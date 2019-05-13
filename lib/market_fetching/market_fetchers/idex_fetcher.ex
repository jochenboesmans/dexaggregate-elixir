defmodule MarketFetching.IdexFetcher do
  @moduledoc """
    Fetches the Idex market and updates the global Market accordingly.
  """

  use Task, restart: :permanent

  import MarketFetching.Util

  alias MarketFetching.Pair, as: Pair
  alias MarketFetching.ExchangeMarket, as: ExchangeMarket
  alias MarketFetching.PairMarketData, as: PairMarketData

  @market_endpoint "https://api.idex.market/returnTicker"
  @currencies_endpoint "https://api.idex.market/returnCurrencies"

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
      filter_valid_pairs(market)
      |> Enum.map(fn {k, p} ->
        [base_symbol, quote_symbol] = String.split(k, "_")
        %Pair{
          base_symbol: base_symbol,
          quote_symbol: quote_symbol,
          base_address: c[base_symbol],
          quote_address: c[quote_symbol],
          market_data: %PairMarketData{
            exchange: :idex,
            last_price: parse_float(p["last"]),
            current_bid: parse_float(p["highestBid"]),
            current_ask: parse_float(p["lowestAsk"]),
            base_volume: parse_float(p["baseVolume"]),
          }
        }
      end)

    %ExchangeMarket{
      exchange: :idex,
      market: complete_market,
    }
  end

  defp currencies() do
    fetch_currencies()
    |> format_currencies()
  end

  def fetch_market() do
    case post_and_decode(@market_endpoint) do
      {:ok, market} ->
        market
      {:error, _message} ->
        nil
    end
  end

  def fetch_currencies() do
    case post_and_decode(@currencies_endpoint) do
      {:ok, currencies} ->
        currencies
      {:error, _message} ->
        nil
    end
  end

  defp format_currencies(currencies) do
    Enum.reduce(currencies, %{}, fn {k, c}, acc ->
      Map.put(acc, k, c["address"])
    end)
  end

  defp filter_valid_pairs(market) do
    Enum.filter(market, fn {_k, p} ->
      values_to_check = [
        p["last"],
        p["highestBid"],
        p["lowestAsk"],
        p["baseVolume"],
      ]
      Enum.all?(values_to_check, fn v -> valid_float?(Float.parse(v)) end)
    end)
  end
end
