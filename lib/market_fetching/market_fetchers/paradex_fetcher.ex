defmodule MarketFetching.ParadexFetcher do
	@moduledoc """
		Fetches the Paradex market and updates the global Market accordingly.
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
		|> Stream.map(fn _x -> complete_market() end)
		|> Enum.each(fn x -> Market.update(x) end)
	end

	defp complete_market() do
		complete_market = Enum.map(market(), fn p ->
			%Pair{
				base_symbol: p.base_symbol,
				quote_symbol: p.quote_symbol,
				base_address: p.base_address,
				quote_address: p.quote_address,
				market_data: p.market_data,
			}
		end)

		%ExchangeMarket{
			exchange: :paradex,
			market: complete_market
		}
	end

	defp market() do
		fetch_market()
		|> transform_market()
	end

	defp fetch_market() do
		fetch_and_decode("https://api.paradex.io/consumer/v1/markets")
	end

	defp fetch_currencies() do
		fetch_and_decode("https://api.paradex.io/api/v1/tokens")
	end

	defp fetch_and_decode(url) do
		%HTTPoison.Response{body: received_body} = HTTPoison.get!(url, [{"API-KEY", api_key()}])

		case Poison.decode(received_body) do
			{:ok, decoded_market} ->
				decoded_market
			{:error, _message} ->
				nil
		end
	end

	defp transform_market(market) do
		Enum.map(market, fn p ->
			[q, b] = String.split(p["id"], "-")
			%Pair{
				base_symbol: b,
				quote_symbol: q,
				base_address: p["baseTokenAddress"],
				quote_address: p["quoteTokenAddress"],
				market_data: %PairMarketData{
					exchange: :paradex,
					last_traded: elem(Float.parse(p["ticker"]["price"]), 0),
					current_bid: elem(Float.parse(p["ticker"]["bestBid"]), 0),
					current_ask: elem(Float.parse(p["ticker"]["bestAsk"]), 0),
					base_volume: elem(Float.parse(p["stats"]["volume24Hour"]), 0),
					quote_volume: nil,
				}
			}
		end)
	end

	defp api_key() do
		Application.get_env(:dexaggregate_elixir, :PARADEX_API_KEY)
	end
end
