defmodule IdexFetcher do
  @moduledoc """
  Fetches the Idex market.
  """
  use GenServer

  def start_link(_initial_state) do
    GenServer.start_link(__MODULE__, [%{}], name: __MODULE__)
  end

  @impl true
  def init(_initial_market) do
    {:ok, poll()}
  end

  @impl true
  def handle_call(:get, _from, market) do
    {:reply, market, market}
  end

  @impl true
  def handle_cast({:update, new_market}, _market) do
    {:noreply, new_market}
  end

  def get_market() do
    GenServer.call(__MODULE__, :get)
  end

  def poll() do
    Stream.interval(10_000)
    |> Stream.map(fn _x -> complete_market() end)
    |> Enum.each(fn x -> GenServer.cast(__MODULE__, {:update, x}) end)
  end

  defp complete_market() do
    m = market()
    c = currencies()

    complete_market =
      Enum.map(m, fn p ->
        %Pair{
          base_symbol: p.base_symbol,
          quote_symbol: p.quote_symbol,
          base_address: c[p.base_symbol],
          quote_address: c[p.quote_symbol],
          market_data: p.market_data
        }
      end)

    %ExchangeMarket{
      exchange: :idex,
      market: complete_market
    }
  end

  defp market() do
    fetch_market()
    |> transform_market()
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

  defp transform_market(market) do
    filter_valid_pairs(market)
    |> Enum.map(fn {k, p} ->
      [base_symbol, quote_symbol] = String.split(k, "_")
      %Pair{
        base_symbol: base_symbol,
        quote_symbol: quote_symbol,
        base_address: "",
        quote_address: "",
        market_data: %PairMarketData{
          last_traded: elem(Float.parse(p["last"]), 0),
          current_bid: elem(Float.parse(p["highestBid"]), 0),
          current_ask: elem(Float.parse(p["lowestAsk"]), 0),
          base_volume: elem(Float.parse(p["baseVolume"]), 0),
          quote_volume: elem(Float.parse(p["quoteVolume"]), 0)
        }
      }
    end)
  end

  defp transform_currencies(currencies) do
    Enum.reduce(currencies, %{}, fn {k, c}, acc ->
      Map.put(acc, k, c["address"])
    end)
  end
end
