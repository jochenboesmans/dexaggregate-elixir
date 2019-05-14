defmodule MarketFetching.IdexFetcher do
  @moduledoc """
    Fetches the Idex market and updates the global Market accordingly.
  """

  use Task, restart: :permanent

  import MarketFetching.Util

  alias MarketFetching.Pair
  alias MarketFetching.ExchangeMarket
  alias MarketFetching.PairMarketData

  @market_endpoint "https://api.idex.market/returnTicker"
  @currencies_endpoint "https://api.idex.market/returnCurrencies"

  @poll_interval 10_000

  # Makes sure private functions are testable.
  @compile if Mix.env == :test, do: :export_all

  def start_link(_arg) do
    Task.start_link(__MODULE__, :poll, [])
  end

  def poll() do
    Stream.interval(@poll_interval)
    |> Stream.map(fn _x -> exchange_market() end)
    |> Enum.each(fn x -> Market.update(x) end)
  end

  def exchange_market() do
    fetch_market()
    |> assemble_exchange_market()
  end

  def try_get_valid_pair({k, p}, c) do
    %{
      "last" => lp,
      "highestBid" => cb,
      "lowestAsk" => ca,
      "baseVolume" => bv,
    } = p
    [bs, qs] = String.split(k, "_")
    [ba, qa] = [c[bs], c[qs]]

    %Pair{
      base_symbol: bs,
      quote_symbol: qs,
      base_address: ba,
      quote_address: qa,
      market_data: %PairMarketData{
        exchange: :idex,
        last_price: parse_float(lp),
        current_bid: parse_float(cb),
        current_ask: parse_float(ca),
        base_volume: parse_float(bv),
      }
    }
  end

  defp assemble_exchange_market(market) do
    c = currencies()

    complete_market =
      Enum.reduce(market, [], fn (p, acc) ->
        case try_get_valid_pair(p, c) do
          nil ->
            acc
          valid_pair ->
            [valid_pair | acc]
        end
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
end
