defmodule MarketFetching.MarketFetchers.IdexFetcher do
  @moduledoc """
    Fetches the Idex market and updates the global Market accordingly.
  """
  use Task, restart: :permanent
  alias MarketFetching.Pair, as: Pair
  alias MarketFetching.ExchangeMarket, as: ExchangeMarket
  alias MarketFetching.PairMarketData, as: PairMarketData

  def start_link(_arg) do
    Task.start_link(__MODULE__, :poll, [])
  end

  defp poll() do
    Stream.interval(10_000)
    |> Stream.map(fn _x -> exchange_market() end)
    |> Enum.each(fn x -> Market.update(x) end)
  end

  defp exchange_market() do
    fetch_market()
    |> assemble_exchange_market()
  end

  defp assemble_exchange_market(market) do
    c = currencies()

    complete_market =
      filter_valid_pairs(market)
      |> Enum.map(fn {k, p} ->
        [base_symbol, quote_symbol] = String.split(k, "_")
        %Pair{
          base_symbol: base_symbol,
          quote_symbol: quote_symbol,
          base_address: c[p.base_symbol],
          quote_address: c[p.quote_symbol],
          market_data: %PairMarketData{
            exchange: :idex,
            last_traded: elem(Float.parse(p["last"]), 0),
            current_bid: elem(Float.parse(p["highestBid"]), 0),
            current_ask: elem(Float.parse(p["lowestAsk"]), 0),
            base_volume: elem(Float.parse(p["baseVolume"]), 0),
            quote_volume: elem(Float.parse(p["quoteVolume"]), 0)
          }
        }
      end)

    %ExchangeMarket{
      exchange: :idex,
      market: complete_market,
    }
  end

  @doc """
    Transforms a given map of currencies to a map with token symbols as keys and token addresses as values.

  ## Examples
    iex> IdexFetcher.transform_currencies(%{
        "ETH" => %{
          "address" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
          "decimals" => 18,
          "name" => "Ether"
        }
      })
    %{"ETH" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"}
  """
  defp transform_currencies(currencies) do
    Enum.reduce(currencies, %{}, fn {k, c}, acc ->
      Map.put(acc, k, c["address"])
    end)
  end

  defp currencies() do
    fetch_currencies()
    |> transform_currencies()
  end

  defp fetch_currencies() do
    fetch_and_decode("https://api.idex.market/returnCurrencies")
  end

  defp fetch_market() do
    fetch_and_decode("https://api.idex.market/returnTicker")
  end

  defp fetch_and_decode(url) do
    %HTTPoison.Response{body: received_body} = HTTPoison.post!(url, Poison.encode!(%{}))

    case Poison.decode(received_body) do
      {:ok, data} ->
        data
      {:error, _message} ->
        nil
    end
  end

  defp valid_float?(float) do
    case float do
      :error -> false
      {0.0, ""} -> false
      {_valid_value, ""} -> true
    end
  end

  defp filter_valid_pairs(market) do
    Enum.filter(market, fn {_k, p} ->
      values_to_check = [
        p["last"],
        p["highestBid"],
        p["lowestAsk"],
        p["baseVolume"],
        p["quoteVolume"]
      ]
      Enum.all?(values_to_check, fn v -> valid_float?(Float.parse(v)) end)
    end)
  end
end
