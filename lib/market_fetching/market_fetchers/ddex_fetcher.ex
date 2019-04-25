defmodule MarketFetching.DdexFetcher do
	@moduledoc """
		Fetches the Ddex market and updates the global Market accordingly.

		!!! Unimplemented boilerplate code.

		TODO: Implement WebSocket client.
	"""
	use Task, restart: :permanent
	alias MarketFetching.ExchangeMarket, as: ExchangeMarket

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

	defp assemble_exchange_market(_market) do
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
			{:error, _message} ->
				nil
		end
	end
end
