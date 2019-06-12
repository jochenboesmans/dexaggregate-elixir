defmodule Dexaggregatex.MarketFetching.KyberFetcher do
  @moduledoc """
  Polls the Kyber market and updates the global Market accordingly.
  """
  use Task, restart: :permanent

  import Dexaggregatex.MarketFetching.{Util, Common}
  alias Dexaggregatex.MarketFetching.Structs.{ExchangeMarket, Pair, PairMarketData}

  @base_api_url "https://api.kyber.network"
  @market_endpoint "market"
  @currencies_endpoint "currencies"
  @poll_interval 5_000

  # Make private functions testable.
  @compile if Mix.env == :test, do: :export_all

	@doc """
	Starts a KyberFetcher process linked to the caller process.
	"""
	@spec start_link(any) :: {:ok, pid}
  def start_link(_arg) do
    Task.start_link(__MODULE__, :poll, [])
  end

	@doc """
	Polls the Kyber market and updates the global Market accordingly.
	"""
	@spec poll() :: any
  def poll() do
    Stream.interval(@poll_interval)
    |> Stream.map(fn _x -> exchange_market() end)
    |> Enum.each(fn x -> maybe_update(x) end)
  end

	@doc """
	Fetches and formats data from the Kyber API to make up the latest Kyber ExchangeMarket.
	"""
  @spec exchange_market() :: ExchangeMarket.t
  def exchange_market() do
    complete_market =
      case get_from_api("#{@base_api_url}/#{@currencies_endpoint}") do
        {:ok, currencies} ->
          case get_from_api("#{@base_api_url}/#{@market_endpoint}") do
            {:ok, market} ->
							c = index_currencies(currencies)
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
                  true -> [market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) | acc]
                  false -> acc
                end
              end)
            :error -> nil
          end
        :error -> nil
      end

    %ExchangeMarket{
      exchange: :kyber,
      market: complete_market,
    }
  end

	@doc """
	Makes a well-formatted market pair based on the given data.
	"""
  @spec market_pair(strings: [String.t], numbers: [number]) :: Pair.t
  defp market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
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

	@doc """
	Retrieves data by fetching from the Kyber API.
	"""
	@spec get_from_api(String.t) :: {:ok, [map]} | :error
  defp get_from_api(url) do
    case fetch_and_decode(url) do
			{:ok, %{"error" => false, "data" => data}} -> {:ok, data}
			_ -> :error
    end
  end
end
