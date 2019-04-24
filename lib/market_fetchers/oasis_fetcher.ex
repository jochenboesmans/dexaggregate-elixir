defmodule MarketFetchers.OasisFetcher do
	@moduledoc """
		Fetches the Oasis market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent

	def start_link(_arg) do
		Task.start_link(__MODULE__, :poll, [])
	end

	defp poll() do
		Stream.interval(10_000)
		|> Stream.map(fn _x -> exchange_market() end)
		|> Enum.each(fn x -> Market.update(x) end)
	end

	defp exchange_market() do
		fetch_market()
		|> assemble_exchange_market()
	end

	defp assemble_exchange_market(market) do
		c = currencies()

		complete_market =
			Enum.map(market, fn p ->
				[base_symbol, quote_symbol] = String.split(p["pair"], "/")
				%Pair{
					base_symbol: base_symbol,
					quote_symbol: quote_symbol,
					base_address: c[p.base_symbol],
					quote_address: c[p.quote_symbol],
					market_data: %PairMarketData{
						exchange: :oasis,
						last_traded: transform_rate(p["last"]),
						current_bid: transform_rate(p["bid"]),
						current_ask: transform_rate(p["ask"]),
						base_volume: transform_rate(p["vol"]),
						quote_volume: nil,
					}
				}
			end)

		%ExchangeMarket{
			exchange: :oasis,
			market: complete_market
		}
	end

	defp market() do
		fetch_market()
		|> transform_market()
	end

	defp currencies() do
		%{
			"MKR" => "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
			"ETH" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
			"DAI" => "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
		}
	end

	defp pairs() do
		[["MKR", "ETH"], ["MKR", "DAI"], ["ETH", "DAI"]]
	end

	defp fetch_market() do
		for [base, quote] <- pairs() do
			fetch_and_decode("http://api.oasisdex.com/v1/markets/#{base}/#{quote}")
		end
	end

	defp fetch_and_decode(url) do
		%HTTPoison.Response{body: received_body} = HTTPoison.get!(url)

		case Poison.decode(received_body) do
			{:ok, %{"data" => decoded_market}} ->
				decoded_market
			{:error, message} ->
				nil
		end
	end

	defp transform_rate(rate) do
		:math.pow(elem(Float.parse(rate), 0), -1)
	end
end
