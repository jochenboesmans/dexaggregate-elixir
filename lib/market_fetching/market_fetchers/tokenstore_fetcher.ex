defmodule Dexaggregatex.MarketFetching.TokenstoreFetcher do
	@moduledoc """
	Polls the Tokenstore market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent

	import Dexaggregatex.MarketFetching.{Util, Common}
	alias Dexaggregatex.MarketFetching.Structs.ExchangeMarket

	@base_api_url "https://v1-1.api.token.store"
	@market_endpoint "ticker"
	@poll_interval 5_000

	# Makes private functions testable.
	@compile if Mix.env == :test, do: :export_all

	@doc """
	Starts a TokenFetcher process linked to the caller process.
	"""
	@spec start_link(any) :: {:ok, pid}
	def start_link(_arg) do
		Task.start_link(__MODULE__, :poll, [])
	end

	@doc """
	Polls the Tokenstore market and updates the global Market accordingly.
	"""
	@spec poll() :: :ok
	def poll() do
		Stream.interval(@poll_interval)
		|> Stream.map(fn _x -> exchange_market() end)
		|> Enum.each(fn x -> maybe_update(x) end)
	end

	@doc """
	Fetches and formats data from the Tokenstore API to make up the latest Tokenstore ExchangeMarket.
	"""
	@spec exchange_market() :: ExchangeMarket.t
	defp exchange_market() do
		pairs =
			case fetch_and_decode("#{@base_api_url}/#{@market_endpoint}") do
				{:ok, market} ->
					Enum.reduce(market, [],  fn ({_k, p}, acc) ->
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
								[generic_market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv], exchange: :tokenstore) | acc]
							false ->
								acc
						end
					end)
				:error ->
					nil
			end

		%ExchangeMarket{
			exchange: :tokenstore,
			pairs: pairs
		}
	end
end
