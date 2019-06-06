defmodule Dexaggregatex.MarketFetching.UniswapFetcher do
	@moduledoc """
		Fetches the Uniswap market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent

	import Dexaggregatex.MarketFetching.Util
	alias Dexaggregatex.MarketFetching.Structs.{Pair, ExchangeMarket, PairMarketData}

	@graph_http "https://api.thegraph.com/subgraphs/name/graphprotocol/uniswap"
	# use ws for subscriptions later.
	#@graph_ws "wss://api.thegraph.com/subgraphs/name/graphprotocol/uniswap"

	@poll_interval 10_000

	# Makes sure private functions are testable.
	@compile if Mix.env == :test, do: :export_all

	def start_link(_arg) do
		Task.start_link(__MODULE__, :poll, [])
	end

	def poll() do
		Stream.interval(@poll_interval)
		|> Stream.map(fn _x -> exchange_market() end)
		|> Enum.each(fn x -> maybe_update(x) end)
	end

	def fetch_data() do
		Neuron.Config.set(url: @graph_http)

		{:ok, %Neuron.Response{body:
			%{"data" =>
				%{"exchanges" => ex}
			}
		}} = Neuron.query("""
			{
				exchanges {
					id
					tokenAddress
					tokenSymbol
					lastPrice
					price
					tradeVolumeEth
					tradeVolumeToken
				}
			}
		""")

		ex
	end

	def exchange_market() do
		complete_market =
			Enum.reduce(fetch_data(), [], fn (e, acc) ->
				%{
					"lastPrice" => lp,
					"price" => cb = ca,
					"tradeVolumeEth" => bv,
					"tokenSymbol" => qs,
					"tokenAddress" => qa
				} = e

				[bs, ba] = ["ETH", eth_address()]

				case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
					true ->
						[market_pair([bs, qs, ba, qa, lp, cb, ca, bv]) | acc]
					false ->
						acc
				end
			end)

		%ExchangeMarket{
			exchange: :uniswap,
			market: complete_market
		}

	end

	defp market_pair([bs, qs, ba, qa, lp, cb, ca, bv]) do
		%Pair{
			base_symbol: bs,
			quote_symbol: qs,
			base_address: ba,
			quote_address: qa,
			market_data: %PairMarketData{
				exchange: :uniswap,
				last_price: safe_power(parse_float(lp), -1),
				current_bid: safe_power(parse_float(cb), -1),
				current_ask: safe_power(parse_float(ca), -1),
				base_volume: parse_float(bv) * safe_power(10, -2)
			}
		}
	end
end
