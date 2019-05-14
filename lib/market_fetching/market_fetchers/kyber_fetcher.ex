defmodule MarketFetching.KyberFetcher do
  @moduledoc """
    Fetches the Kyber market and updates the global Market accordingly.
  """
  use Task, restart: :permanent

  import MarketFetching.Util

  alias MarketFetching.Pair
  alias MarketFetching.ExchangeMarket
  alias MarketFetching.PairMarketData

  @market_endpoint "https://api.kyber.network/market"
  @currencies_endpoint "https://api.kyber.network/currencies"

  # Makes sure private functions are testable.
  @compile if Mix.env == :test, do: :export_all

  def start_link(_arg) do
    Task.start_link(__MODULE__, :poll, [])
  end

  def poll() do
    Stream.interval(10_000)
    |> Stream.map(fn _x -> exchange_market() end)
    |> Enum.each(fn x -> Market.update(x) end)
  end

  def exchange_market() do
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
            last_price: p["last_traded"],
            current_bid: p["current_bid"],
            current_ask: p["current_ask"],
            base_volume: p["eth_24h_volume"],
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

  def fetch_currencies() do
    case fetch_and_decode(@currencies_endpoint) do
      {:ok, %{"data" => currencies}} ->
        currencies
      {:error, _message} ->
        nil
    end
  end

  def fetch_market() do
    case fetch_and_decode(@market_endpoint) do
      {:ok, %{"data" => market}} ->
        market
      {:error, _message} ->
        nil
    end
  end

  defp transform_currencies(currencies) do
    Enum.reduce(currencies, %{}, fn (c, acc) ->
      Map.put(acc, c["symbol"], c["address"])
    end)
  end
end
