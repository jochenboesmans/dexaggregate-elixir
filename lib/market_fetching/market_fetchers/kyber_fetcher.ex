defmodule Dexaggregatex.MarketFetching.KyberFetcher do
  @moduledoc """
    Fetches the Kyber market and updates the global Market accordingly.
  """
  use Task, restart: :permanent

  import Dexaggregatex.MarketFetching.Util
  alias Dexaggregatex.MarketFetching.Structs.{ExchangeMarket, Pair, PairMarketData}

  @base_api_url "https://api.kyber.network"
  @market_endpoint "market"
  @currencies_endpoint "currencies"

  @poll_interval 10_000

  # Makes sure private functions are testable.
  @compile if Mix.env == :test, do: :export_all

  def start_link(_arg) do
    Task.start_link(__MODULE__, :poll, [])
  end

  def poll() do
    Stream.interval(@poll_interval)
    |> Stream.map(fn _x -> exchange_market() end)
    |> Enum.each(fn x -> maybe_update(x) end)
  end

  def exchange_market() do
    complete_market =
      case get_from_api("#{@base_api_url}/#{@currencies_endpoint}") do
        {:ok, currencies} ->
          c = transform_currencies(currencies)
          case get_from_api("#{@base_api_url}/#{@market_endpoint}") do
            {:ok, market} ->
              Enum.reduce(market, [], fn (p, acc) ->
                %{
                  "base_symbol" => bs,
                  "quote_symbol" => qs,
                  "last_traded" => lp,
                  "current_bid" => cb,
                  "current_ask" => ca,
                  "token_24h_volume" => bv
                } = p
                [ba, qa] = [c[bs], c[qs]]

                case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
                  true ->
                    [market_pair([bs, qs, ba, qa, lp, cb, ca, bv]) | acc]
                  false ->
                    acc
                end
              end)
            {:error, _message} ->
              nil
          end
        {:error, _message} ->
          nil
      end

    %ExchangeMarket{
      exchange: :kyber,
      market: complete_market,
    }
  end

  defp market_pair([bs, qs, ba, qa, lp, cb, ca, bv]) do
    %Pair{
      base_symbol: bs,
      quote_symbol: qs,
      base_address: ba,
      quote_address: qa,
      market_data: %PairMarketData{
        exchange: :kyber,
        last_price: safe_power(parse_float(lp), -1),
        current_bid: safe_power(parse_float(cb), -1),
        current_ask: safe_power(parse_float(ca), -1),
        base_volume: parse_float(bv),
      }
    }
  end

  defp get_from_api(url) do
    case fetch_and_decode(url) do
      {:ok, %{"data" => data}} ->
        {:ok, data}
      {:error, message} ->
        {:error, message}
    end
  end

  defp transform_currencies(currencies) do
    Enum.reduce(currencies, %{}, fn (c, acc) ->
      Map.put(acc, c["symbol"], c["address"])
    end)
  end
end
