defmodule MarketFetching.MarketFetchers.TokenstoreFetcher do
	@moduledoc """
		Fetches the Tokenstore market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent
	alias MarketFetching.Util, as: Util
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
		eth_address = Util.eth_address()

		complete_market =
			Enum.map(market, fn {_p, v} ->
				%Pair{
					base_symbol: "ETH",
					quote_symbol: v["symbol"],
					base_address: eth_address,
					quote_address: v["tokenAddr"],
					market_data: %PairMarketData{
						exchange: :tokenstore,
						last_traded: v["last"],
						current_bid: v["bid"],
						current_ask: v["ask"],
						base_volume: v["baseVolume"],
						quote_volume: v["quoteVolume"],
					}
				}
			end)

		%ExchangeMarket{
			exchange: :tokenstore,
			market: complete_market,
		}
	end

	defp fetch_market() do
		fetch_and_decode("https://v1-1.api.token.store/ticker")
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
