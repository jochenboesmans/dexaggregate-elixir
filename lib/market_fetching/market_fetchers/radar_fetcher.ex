defmodule MarketFetching.RadarFetcher do
	@moduledoc """
		Fetches the Radar Relay market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent
	alias MarketFetching.Pair, as: Pair
	alias MarketFetching.ExchangeMarket, as: ExchangeMarket
	alias MarketFetching.PairMarketData, as: PairMarketData

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

	defp exchange_market() do
		fetch_market()
		|> assemble_exchange_market()
	end

	defp assemble_exchange_market(market) do
		complete_market =
			Enum.map(market, fn p ->
				[q, b] = String.split(p["id"], "-")
				%Pair{
					base_symbol: b,
					quote_symbol: q,
					base_address: p["baseTokenAddress"],
					quote_address: p["quoteTokenAddress"],
					market_data: %PairMarketData{
						exchange: :radar,
						last_traded: elem(Float.parse(p["ticker"]["price"]), 0),
						current_bid: elem(Float.parse(p["ticker"]["bestBid"]), 0),
						current_ask: elem(Float.parse(p["ticker"]["bestAsk"]), 0),
						base_volume: elem(Float.parse(p["stats"]["volume24Hour"]), 0),
						quote_volume: nil,
					}
				}
			end)

		%ExchangeMarket{
			exchange: :radar,
			market: complete_market
		}
	end

	defp fetch_market() do
		fetch_and_decode("https://api.radarrelay.com/v2/markets?include=base,ticker,stats")
	end

	defp fetch_and_decode(url) do
		%HTTPoison.Response{body: received_body} = HTTPoison.get!(url)

		case Poison.decode(received_body) do
			{:ok, decoded_market} ->
				decoded_market
			{:error, _message} ->
				nil
		end
	end
end