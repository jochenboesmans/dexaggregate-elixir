defmodule Dexaggregatex.MarketFetching.RadarFetcher do
	@moduledoc """
	Fetches the Radar market and updates the global Market accordingly.
	"""
	# TODO: Implement WebSocket client whenever Radar implements TICKER and CANDLE topics.
	use Task, restart: :permanent

	import Dexaggregatex.MarketFetching.{Util, Common}
	alias Dexaggregatex.MarketFetching.Structs.ExchangeMarket

	@base_api_url "https://api.radarrelay.com/v2"
	@market_endpoint "markets"
	@poll_interval 5_000

	# Makes private functions testable.
	@compile if Mix.env == :test, do: :export_all

	@doc """
	Starts a RadarFetcher process linked to the caller process.
	"""
	@spec start_link(any) :: {:ok, pid}
	def start_link(_arg) do
		Task.start_link(__MODULE__, :poll, [])
	end

	@doc """
	Polls the Radar market and updates the global Market accordingly.
	"""
	@spec poll() :: :ok
	def poll() do
		Stream.interval(@poll_interval)
		|> Stream.map(fn _x -> exchange_market() end)
		|> Enum.each(fn x -> maybe_update(x) end)
	end

	@doc """
	Fetches and formats data from the Radar API to make up the latest Radar ExchangeMarket.
	"""
	@spec exchange_market() :: ExchangeMarket.t
	def exchange_market() do
		pairs =
			case fetch_and_decode("#{@base_api_url}/#{@market_endpoint}?include=base,ticker,stats") do
				{:ok, market} ->
					Enum.reduce(market, [], fn (p, acc) ->
						%{
							"id" => id,
							"baseTokenAddress" => qa,
							"quoteTokenAddress" => ba,
							"ticker" => %{
								"price" => lp,
								"bestBid" => cb,
								"bestAsk" => ca
							},
							"stats" => %{
								"volume24Hour" => bv
							}
						} = p
						[qs, bs] = String.split(id, "-")

						case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
							true ->
								[generic_market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv], exchange: :radar) | acc]
							false ->
								acc
						end
					end)
				:error -> nil
			end

		%ExchangeMarket{
			exchange: :radar,
			pairs: pairs
		}
	end
end