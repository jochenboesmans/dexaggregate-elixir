defmodule MarketFetchers.KyberFetcher do
  @moduledoc """
  Fetches the Kyber market.
  """
  use Task
  alias MarketFetchers.Structs.Pair
  alias MarketFetchers.Structs.PairMarketData

  def start_link(_arg) do
    Task.start_link(&poll/0)
  end

  def poll() do
    Stream.interval(10_000)
    |> Stream.map(fn _x -> complete_market() end)
    |> Enum.each(fn x -> IO.inspect(x) end)
  end

  def complete_market() do
    m = market()
    c = currencies()
    Enum.map(m, fn p ->
      %Pair{
        base_symbol: p.base_symbol,
        quote_symbol: p.quote_symbol,
        base_address: c[p.base_symbol],
        quote_address: c[p.quote_symbol],
        market_data: p.market_data
      }
    end)
  end

  def market() do
    fetch_market()
    |> transform_market()
  end

  def currencies() do
    fetch_currencies()
    |> transform_currencies()
  end

  def fetch_currencies() do
    fetch_and_decode("https://api.kyber.network/currencies")
  end

  def fetch_market() do
    fetch_and_decode("https://api.kyber.network/market")
  end

  def fetch_and_decode(url) do
    %HTTPoison.Response{body: received_body} = HTTPoison.get!(url)
    case Poison.decode(received_body) do
      {:ok, %{"data" => decoded_market}} ->
        decoded_market
      {:error, _message} ->
        nil
    end
  end

  def transform_market(market) do
    Enum.map(market, fn p ->
      %Pair{
        base_symbol: p["base_symbol"],
        quote_symbol: p["quote_symbol"],
        base_address: "",
        quote_address: "",
        market_data: %PairMarketData{
          last_traded: p["last_traded"],
          current_bid: p["current_bid"],
          current_ask: p["current_ask"],
          base_volume: p["eth_24h_volume"],
          quote_volume: p["token_24h_volume"]
        }
       }
    end)
  end

  def transform_currencies(currencies) do
    Enum.reduce(currencies, %{}, fn (c, acc) ->
      Map.put(acc, c["symbol"], c["address"])
    end)
  end

end
