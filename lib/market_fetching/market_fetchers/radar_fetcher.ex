defmodule MarketFetching.RadarFetcher do
	@moduledoc """
		Fetches the Radar Relay market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent

	import MarketFetching.Util

	alias MarketFetching.Pair, as: Pair
	alias MarketFetching.ExchangeMarket, as: ExchangeMarket
	alias MarketFetching.PairMarketData, as: PairMarketData

	@base_api_url "https://api.radarrelay.com/v2"
	@market_endpoint "markets"

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
		try_get_market()
		|> assemble_exchange_market()
	end

	defp try_get_market() do
		case fetch_and_decode("#{@base_api_url}/#{@market_endpoint}?include=base,ticker,stats") do
			{:ok, market} ->
				market
			{:error, _message} ->
				nil
		end
end

	defp assemble_exchange_market(market) do
		complete_market =
			Enum.map(market, fn p ->
				[qs, bs] = String.split(p["id"], "-")
				%Pair{
					base_symbol: bs,
					quote_symbol: qs,
					base_address: p["baseTokenAddress"],
					quote_address: p["quoteTokenAddress"],
					market_data: %PairMarketData{
						exchange: :radar,
						last_price: parse_float(p["ticker"]["price"]),
						current_bid: parse_float(p["ticker"]["bestBid"]),
						current_ask: parse_float(p["ticker"]["bestAsk"]),
						base_volume: parse_float(p["stats"]["volume24Hour"]),
					}
				}
			end)

		%ExchangeMarket{
			exchange: :radar,
			market: complete_market
		}
	end
end