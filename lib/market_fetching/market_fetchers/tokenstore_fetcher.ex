defmodule MarketFetching.TokenstoreFetcher do
	@moduledoc """
		Fetches the Tokenstore market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent

	import MarketFetching.Util

	alias MarketFetching.Pair, as: Pair
	alias MarketFetching.ExchangeMarket, as: ExchangeMarket
	alias MarketFetching.PairMarketData, as: PairMarketData

	@base_api_url "https://v1-1.api.token.store"
	@market_endpoint "ticker"

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
		fetch_and_decode("#{@base_api_url}/#{@market_endpoint}")
		|> assemble_exchange_market()
	end

	defp holds_valid_values?(p) do
		strings = [
			p["symbol"],
			p["tokenAddr"],
		]
		numbers = [
			p["last"],
			p["bid"],
			p["ask"],
			p["baseVolume"],
			p["quoteVolume"]
		]
		Enum.all?(strings, fn s -> valid_string?(s) end)
		&& Enum.all?(numbers, fn n -> valid_float?(n) end)
	end

	defp valid_string?(s) do
		cond do
			!is_binary(s) -> false
			s == "" -> false
			true -> true
		end
	end

	defp assemble_exchange_market(market) do
		complete_market =
			Enum.reduce(market, [],  fn ({_k, p}, acc) ->
				case holds_valid_values?(p) do
					true ->
						market_pair =
							%Pair{
								base_symbol: "ETH",
								quote_symbol: p["symbol"],
								base_address: eth_address(),
								quote_address: p["tokenAddr"],
								market_data: %PairMarketData{
									exchange: :tokenstore,
									last_price: p["last"],
									current_bid: p["bid"],
									current_ask: p["ask"],
									base_volume: p["baseVolume"],
									quote_volume: p["quoteVolume"],
								}
							}
						[market_pair | acc]
					false ->
						acc
				end
			end)

		%ExchangeMarket{
			exchange: :tokenstore,
			market: complete_market,
		}
	end
end
