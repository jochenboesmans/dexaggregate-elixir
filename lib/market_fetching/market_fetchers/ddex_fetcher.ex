defmodule MarketFetching.MarketFetchers.DdexFetcher do
	@moduledoc """
		Fetches the Ddex market and updates the global Market accordingly.

		Unimplemented boilerplate code.

		TODO: Implement WebSocket client.
	"""
	use Task, restart: :permanent
	alias MarketFetching.Pair, as: Pair
	alias MarketFetching.ExchangeMarket, as: ExchangeMarket
	alias MarketFetching.PairMarketData, as: PairMarketData

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
		#TODO: Implement
		complete_market = nil

		%ExchangeMarket{
			exchange: :ddex,
			market: complete_market
		}
	end

	defp currencies() do
		#TODO: Implement.
		fetch_and_decode(nil)
	end

	def fetch_market() do
		#TODO: Implement.
		fetch_and_decode(nil)
	end

	defp fetch_and_decode(url) do
		#TODO: Implement.
		%HTTPoison.Response{body: received_body} = HTTPoison.get!(url)

		case Poison.decode(received_body) do
			{:ok, %{"data" => decoded_market}} ->
				decoded_market
			{:error, message} ->
				nil
		end
	end
end