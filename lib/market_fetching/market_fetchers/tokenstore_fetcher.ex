defmodule MarketFetching.TokenstoreFetcher do
	@moduledoc """
		Fetches the Tokenstore market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent

	import MarketFetching.Util

	alias MarketFetching.Pair
	alias MarketFetching.ExchangeMarket
	alias MarketFetching.PairMarketData

	@base_api_url "https://v1-1.api.token.store"
	@market_endpoint "ticker"

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

	defp exchange_market() do
		complete_market =
			fetch_and_decode("#{@base_api_url}/#{@market_endpoint}")
			|> Enum.reduce([],  fn ({_k, p}, acc) ->
				%{
					"last" => lp,
					"bid" => cb,
					"ask" => ca,
					"baseVolume" => bv,
					"symbol" => qs,
					"tokenAddr" => qa
				} = p
				[bs, ba] = ["ETH", eth_address()]

				case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
					true ->
						[generic_market_pair([bs, qs, ba, qa, lp, cb, ca, bv], :tokenstore) | acc]
					false ->
						acc
				end
			end)

		%ExchangeMarket{
			exchange: :tokenstore,
			market: complete_market
		}
	end
end
