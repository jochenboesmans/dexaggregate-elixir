defmodule Dexaggregatex.MarketFetching.UniswapFetcher do
	@moduledoc """
	Polls the Uniswap market and updates the global market accordingly.
	"""
	use Task, restart: :permanent

	import Dexaggregatex.MarketFetching.{Util, Common}
	alias Dexaggregatex.MarketFetching.Structs.{Pair, ExchangeMarket, PairMarketData}

	@graph_http "https://api.thegraph.com/subgraphs/name/graphprotocol/uniswap"
	# Use ws for subscriptions later.
	# @graph_ws "wss://api.thegraph.com/subgraphs/name/graphprotocol/uniswap"
	@poll_interval 5_000

	# Make private functions testable.
	@compile if Mix.env == :test, do: :export_all

	@doc """
	Starts a UniswapFetcher process linked to the caller process.
	"""
	@spec start_link(any) :: {:ok, pid}
	def start_link(_arg) do
		Task.start_link(__MODULE__, :poll, [])
	end

	@doc """
	Polls the Uniswap market and updates the global Market accordingly.
	"""
	@spec poll() :: any
	def poll() do
		Stream.interval(@poll_interval)
		|> Stream.map(fn _x -> exchange_market() end)
		|> Enum.each(fn x -> maybe_update(x) end)
	end

	@doc """
	Fetches and formats data from the Uniswap subgraph to make up the latest Uniswap ExchangeMarket.
	"""
	@spec exchange_market() :: ExchangeMarket.t
	def exchange_market() do
		complete_market =
			case fetch_data() do
				{:ok, %{exchanges: exs, exchangeDayDatas: edds}} ->
					Enum.reduce(exs, [], fn (e, acc) ->
						%{
							"id" => id,
							"lastPrice" => lp,
							"price" => cb = ca,
							"tokenSymbol" => qs,
							"tokenAddress" => qa
						} = e
						[bs, ba] = ["ETH", eth_address()]

						case Enum.find(edds, fn edd -> edd["exchangeAddress"] == id end) do
							nil ->
								acc
							not_nil ->
								%{"ethVolume" => bv} = not_nil
								case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
									true ->
										[market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) | acc]
									false ->
										acc
								end
						end
					end)
				:error ->
					nil
			end

		%ExchangeMarket{
			exchange: :uniswap,
			market: complete_market
		}
	end

	@doc """
	Makes a well-formatted market pair based on the given data.
	"""
	@spec market_pair(strings: [String.t], numbers: [number]) :: Pair.t
	defp market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
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
				base_volume: parse_float(bv)
			}
		}
	end

	@doc """
	Retrieves data by fetching from the Uniswap subgraph.
	"""
	@spec fetch_data() :: {:ok, %{exchanges: [map], exchangeDayDatas: [map]}} | :error
	def fetch_data() do
		Neuron.Config.set(url: @graph_http)

		query = Neuron.query("""
			{
				exchanges (first: 100, orderBy: tradeVolumeEth, orderDirection: desc) {
					id
					tokenAddress
					tokenSymbol
					lastPrice
					price
				}
				exchangeDayDatas (first: 100, orderBy: ethVolume, orderDirection: desc) {
					exchangeAddress,
					ethVolume
				}
			}
		""")

		case query do
			{:ok, %Neuron.Response{body:
				%{"data" =>
					%{"exchanges" => exs, "exchangeDayDatas" => edds}
				}
			}} -> {:ok, %{exchanges: exs, exchangeDayDatas: edds}}
			_ -> :error
		end
	end
end
