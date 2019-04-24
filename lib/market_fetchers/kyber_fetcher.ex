defmodule MarketFetchers.KyberFetcher do
  @moduledoc """
    Fetches the Kyber market and updates the global Market accordingly.
  """
  use Task, restart: :permanent

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
      Enum.map(market, fn p ->
        %Pair{
          base_symbol: p["base_symbol"],
          quote_symbol: p["quote_symbol"],
          base_address: c[p["base_symbol"]],
          quote_address: c[p["quote_symbol"]],
          market_data: %PairMarketData{
            exchange: :kyber,
            last_traded: p["last_traded"],
            current_bid: p["current_bid"],
            current_ask: p["current_ask"],
            base_volume: p["eth_24h_volume"],
            quote_volume: p["token_24h_volume"],
          }
        }
      end)

    %ExchangeMarket{
      exchange: :kyber,
      market: complete_market,
    }
  end

  defp currencies() do
    fetch_currencies()
    |> transform_currencies()
  end

  defp fetch_currencies() do
    fetch_and_decode("https://api.kyber.network/currencies")
  end

  defp fetch_market() do
    fetch_and_decode("https://api.kyber.network/market")
  end

  defp fetch_and_decode(url) do
    %HTTPoison.Response{body: received_body} = HTTPoison.get!(url)

    case Poison.decode(received_body) do
      {:ok, %{"data" => decoded_market}} ->
        decoded_market
      {:error, _message} ->
        nil
    end
  end

  defp transform_currencies(currencies) do
    Enum.reduce(currencies, %{}, fn c, acc ->
      Map.put(acc, c["symbol"], c["address"])
    end)
  end
end
