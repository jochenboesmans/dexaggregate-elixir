defmodule Dexaggregatex.Market.Server do
	@moduledoc """
	Stateful process maintaining the global market model.
	"""
	use GenServer

	alias Dexaggregatex.Market.Structs.{Market, LastUpdate, ExchangeMarketData}
	alias Dexaggregatex.Market.Structs.Pair, as: MarketPair
	alias Dexaggregatex.MarketFetching.Structs.{ExchangeMarket, PairMarketData}
	alias Dexaggregatex.MarketFetching.Structs.Pair, as: MarketFetchingPair
	alias Dexaggregatex.API.Endpoint

	import Dexaggregatex.Market.Util

	@doc """
	Start a Market process linked to the current process.
	"""
	@spec start_link(any) :: GenServer.on_start
	def start_link(_options) do
		GenServer.start_link(__MODULE__, nil, name: __MODULE__)
	end

	@doc """
	Initializes the market with a clean state.
	"""
	@impl true
	@spec init(term) :: {:ok, map}
	def init(_initial_market) do
		{:ok, %{
			market: %Market{pairs: %{}},
			last_update: %LastUpdate{timestamp: nil, utc_time: nil, exchange: nil}
		}}
	end

	@doc """
	Returns the latest unrebased market data, as maintained by this process.
	"""
	@impl true
	@spec handle_call(:get_market, GenServer.from, map) :: {:reply, Market.t, map}
	def handle_call(:get_market, _from,  %{market: m} = state) do
		{:reply, m, state}
	end

	@doc """
	Returns a data structure containing data about the last market update.
	"""
	@impl true
	@spec handle_call(:get_last_update, GenServer.from, map)
				:: {:reply, LastUpdate.t, map}
	def handle_call(:get_last_update, _from, %{last_update: lu} = state) do
		{:reply, lu, state}
	end

	@doc """
	Updates the market with the given pair.
	"""
	@impl true
	@spec handle_cast({:update, MarketFetchingPair.t}, map) :: {:noreply, map}
	def handle_cast({:update, %MarketFetchingPair{} = p}, %{market: m} = state) do
		%MarketFetchingPair{market_data: %PairMarketData{exchange: exchange}} = p
		add_pair_result = add_pair(m, p)
		update_return(add_pair_result, exchange, state)
	end

	@doc """
	Updates the market with the given exchange market.
	"""
	@impl true
	@spec handle_cast({:update, ExchangeMarket.t}, map) :: {:noreply, map}
	def handle_cast({:update, %ExchangeMarket{} = em}, %{market: m} = state) do
		%ExchangeMarket{exchange: exchange} = em
		add_exchange_market_result = add_exchange_market(m, em)
		update_return(add_exchange_market_result, exchange, state)
	end

	@doc """
	Adds a single pair to the market.
	"""
	@spec add_pair(Market.t, MarketFetchingPair.t)
				:: {:no_update, Market.t} | {:update, Market.t}
	defp add_pair(%Market{pairs: pairs}, %MarketFetchingPair{} = p) do
		%MarketFetchingPair{
			base_address: ba,
			quote_address: qa,
			base_symbol: bs,
			quote_symbol: qs,
			market_data: %PairMarketData{
				exchange: ex,
				last_price: lp,
				current_bid: cb,
				current_ask: ca,
				base_volume: bv,
			}
		} = p

		id = pair_id(ba, qa)
		emd = %ExchangeMarketData{
			last_price: lp,
			current_bid: cb,
			current_ask: ca,
			base_volume: bv,
		}

		case Map.has_key?(pairs, id) do
			# Add new entry if Market doesn't have MarketPair yet.
			false ->
				market_entry =
					%MarketPair{
						base_address: ba,
						quote_address: qa,
						base_symbol: bs,
						quote_symbol: qs,
						market_data: %{
							ex => emd
						}
					}
				{:update, %Market{pairs: Map.put(pairs, id, market_entry)}}
			# Append or update ExchangeMarketData of existing MarketPair if it does.
			true ->
				case pairs[id].market_data[ex] == emd do
					true ->
						{:no_update, %Market{pairs: pairs}}
					false ->
						market_entry = %{pairs[id] | market_data: Map.put(pairs[id].market_data, ex, emd)}
						{:update, %Market{pairs: Map.put(pairs, id, market_entry)}}
				end
		end
	end

	@doc """
	Adds all pairs of a given ExchangeMarket to the market.
	"""
	@spec add_exchange_market(Market.t, ExchangeMarket.t)
				:: {:no_update, Market.t} | {:update, Market.t}
	defp add_exchange_market(%Market{} = prev_market, %ExchangeMarket{market: m}) do
		Enum.reduce(m, {:no_update, prev_market}, fn (p, {_update_status, market_acc}) ->
			add_pair(market_acc, p)
		end)
	end

	@spec update_return({atom, Market.t}, atom, map) :: {:noreply, map}
	defp update_return(add_result, exchange, state) do
		case add_result do
			{:no_update, _updated_market} ->
				{:noreply, state}
			{:update, updated_market} ->
				updated_last_update = %LastUpdate{
					timestamp: :os.system_time(:millisecond),
					utc_time: NaiveDateTime.utc_now(),
					exchange: exchange
				}
				trigger_API_broadcast(updated_market)
				{:noreply, %{state | market: updated_market, last_update: updated_last_update}}
		end
	end

	defp trigger_API_broadcast(updated_market) do
		Supervisor.start_link([
			{Task, fn -> Absinthe.Subscription.publish(
										 Endpoint, updated_market,
										 [market: "*", rebased_market: "*", exchanges: "*", last_update: "*"]) end}
		], strategy: :one_for_one)
	end

end
