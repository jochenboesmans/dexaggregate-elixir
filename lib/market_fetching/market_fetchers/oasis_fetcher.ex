defmodule Dexaggregatex.MarketFetching.OasisFetcher do
	@moduledoc """
		Fetches the Oasis market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent

	import Dexaggregatex.MarketFetching.{Util, Common}
	alias Dexaggregatex.MarketFetching.Structs.{ExchangeMarket, Pair, PairMarketData}

  @base_api_url "http://api.oasisdex.com/v1"
  @currencies %{
    "MKR" => "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
    "ETH" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    "DAI" => "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
  }
  @pairs [["MKR", "ETH"], ["MKR", "DAI"], ["ETH", "DAI"]]
	@poll_interval 10_000

  # Make private functions testable.
  @compile if Mix.env == :test, do: :export_all

	@doc """
	Starts a OasisFetcher process linked to the caller process.
	"""
	@spec start_link(any) :: {:ok, pid}
	def start_link(_arg) do
		Task.start_link(__MODULE__, :poll, [])
	end

	@doc """
	Polls the Oasis market and updates the global Market accordingly.
	"""
	@spec poll() :: any
	def poll() do
		Stream.interval(@poll_interval)
		|> Stream.map(fn _x -> exchange_market() end)
		|> Enum.each(fn x -> maybe_update(x) end)
	end

	@doc """
	Fetches and formats data from the Oasis API to make up the latest Oasis ExchangeMarket.
	"""
	@spec exchange_market() :: ExchangeMarket.t
	def exchange_market() do
		c = @currencies

		complete_market =
			Enum.reduce(@pairs, [], fn ([bs, qs], acc) ->
				case fetch_pair(base_symbol: bs, quote_symbol: qs) do
					{:ok, p} ->
						%{
							"pair" => id,
							"last" => lp,
							"bid" => cb,
							"ask" => ca,
							"vol" => bv,
						} = p
						[ba, qa] = [c[bs], c[qs]]

						case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
							true ->
								[market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) | acc]
							false ->
								acc
						end
					:error ->
						acc
				end
			end)

		%ExchangeMarket{
			exchange: :oasis,
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
				exchange: :oasis,
				last_price: safe_power(parse_float(lp), -1),
				current_bid: safe_power(parse_float(cb), -1),
				current_ask: safe_power(parse_float(ca), -1),
				base_volume: parse_float(bv),
			}
		}
	end

	@doc """
	Retrieves data of a pair with the specified base and quote symbols from the Oasis API.
	"""
	@spec fetch_pair(base_symbol: String.t, quote_symbol: String.t) :: {:ok, map} | :error
	defp fetch_pair(base_symbol: bs, quote_symbol: qs) do
		case fetch_and_decode("#{@base_api_url}/markets/#{bs}/#{qs}") do
			{:ok, %{"data" => pair}} ->
				{:ok, pair}
			:error ->
				:error
		end
	end
end
