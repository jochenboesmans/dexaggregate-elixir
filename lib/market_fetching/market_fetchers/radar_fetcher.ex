defmodule MarketFetching.RadarFetcher do
	@moduledoc """
		Fetches the Radar Relay market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent

	import MarketFetching.Util

	alias MarketFetching.Pair
	alias MarketFetching.ExchangeMarket
	alias MarketFetching.PairMarketData

	@base_api_url "https://api.radarrelay.com/v2"
	@market_endpoint "markets"

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
		complete_market =
			case fetch_and_decode("#{@base_api_url}/#{@market_endpoint}?include=base,ticker,stats") do
				{:ok, market} ->
					Enum.reduce(market, [], fn (p, acc) ->
						%{
							"id" => id,
							"baseTokenAddress" => ba,
							"quoteTokenAddress" => qa,
							"ticker" => %{
								"price" => lp,
								"bestBid" => cb,
								"bestAsk" => ca
							},
							"stats" => %{
								"volume24Hour" => bv
							}
						} = p
						[qs, bs] = String.split(id, "-")

						case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
							true ->
								[generic_market_pair([bs, qs, ba, qa, lp, cb, ca, bv], :radar) | acc]
							false ->
								acc
						end
					end)
				{:error, _message} ->
					nil
			end

		%ExchangeMarket{
			exchange: :radar,
			market: complete_market
		}
	end
end