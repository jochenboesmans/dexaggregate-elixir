defmodule Dexaggregatex.MarketFetching.ParadexFetcher do
	@moduledoc """
		Fetches the Paradex market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent

	import Dexaggregatex.MarketFetching.{Util, Common}
	alias Dexaggregatex.MarketFetching.Structs.{Pair, ExchangeMarket, PairMarketData}

  @base_api_url "https://api.paradex.io/api/v1"
  @currencies_endpoint "tokens"
  @market_endpoint "markets"
  @ohlcv_endpoint "ohlcv"
  @ticker_endpoint "ticker"

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
		c = currencies()

		complete_market =
			case fetch_and_decode_with_api_key("#{@base_api_url}/#{@market_endpoint}") do
				{:ok, market} ->
					Enum.reduce(market, [], fn (p, acc) ->
						%{"baseToken" => bs,
							"quoteToken" => qs,
							"symbol" => id
						} = p
						bv = ohlcv(id)
						[lp, cb, ca] = ticker(id)
						%{^bs => ba, ^qs => qa} = c

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

		%ExchangeMarket{
			exchange: :paradex,
			market: complete_market
		}
	end

	defp market_pair([bs, qs, ba, qa, lp, cb, ca, bv]) do
		%Pair{
			base_symbol: bs,
			quote_symbol: qs,
			base_address: ba,
			quote_address: qa,
			market_data: %PairMarketData{
				exchange: :paradex,
				last_price: safe_power(parse_float(lp), -1),
				current_bid: safe_power(parse_float(cb), -1),
				current_ask: safe_power(parse_float(ca), -1),
				base_volume: parse_float(bv)
			}
		}
	end

	defp currencies() do
		case fetch_and_decode_with_api_key("#{@base_api_url}/#{@currencies_endpoint}") do
			{:ok, currencies} -> currencies
			{:error, _message} -> nil
		end
		|> Enum.reduce(%{}, fn (c, acc) -> Map.put(acc, c["symbol"], c["address"]) end)
	end

	defp ohlcv(id) do
		case fetch_and_decode_with_api_key("#{@base_api_url}/#{@ohlcv_endpoint}?market=#{id}&period=1d&amount=1") do
			{:ok, %{"error" => _}} -> nil
			{:ok, [%{"volume" => vol}]} -> vol
			{:error, _message} -> nil
		end
	end

	defp ticker(id) do
		case fetch_and_decode_with_api_key("#{@base_api_url}/#{@ticker_endpoint}?market=#{id}") do
			{:ok, %{"error" => _}} -> [nil, nil, nil]
			{:ok, [%{"lastPrice" => last, "bestBid" => bid, "bestAsk" => ask}]} -> [last, bid, ask]
			{:error, _message} -> [nil, nil, nil]
		end
	end

	defp fetch_and_decode_with_api_key(url) do
		[api_key: key] = Application.get_env(:dexaggregatex, __MODULE__, :api_key)
		fetch_and_decode(url, [{"API-KEY", key}])
	end
end
