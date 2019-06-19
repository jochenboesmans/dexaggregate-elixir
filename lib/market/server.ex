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
	alias Dexaggregatex.Market.Rebasing
	import Dexaggregatex.Market.Util

	# Makes sure private functions are testable.
	@compile if Mix.env == :test, do: :export_all

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
			last_update: %LastUpdate{utc_time: nil, pair: nil}
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
		add_result = add_pair(m, p)
		update_return(add_result, state)
	end

	@doc """
	Updates the market with the given exchange market.
	"""
	@impl true
	@spec handle_cast({:update, ExchangeMarket.t}, map) :: {:noreply, map}
	def handle_cast({:update, %ExchangeMarket{} = em}, %{market: m} = state) do
		add_result = add_exchange_market(m, em)
		update_return(add_result, state)
	end

	def handle_cast({:eat_swept_market, %{swept_market: %Market{} = sm, removed_pairs: rp}}, state) do
		Rebasing.Neighbors.remove_pairs(rp)
		Rebasing.Cache.clear()
		{:noreply, %{state | market: sm}}
	end

	@doc """
	Adds a single pair to the market.
	"""
	@spec add_pair(Market.t, MarketFetchingPair.t)
				:: {:no_update, Market.t, Pair.t} | {:update, Market.t, Pair.t}
	defp add_pair(%Market{pairs: pairs} = m, %MarketFetchingPair{} = p) do
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
			timestamp: :os.system_time(:millisecond)
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
				new_market = %Market{pairs: Map.put(pairs, id, market_entry)}
				Rebasing.Neighbors.add_pairs([market_entry], new_market)
				Rebasing.Cache.clear()
				{:update, new_market, market_entry}
			# Append or update ExchangeMarketData of existing MarketPair if it does.
			true ->
				case Map.has_key?(pairs[id].market_data, ex) do
					false ->
						market_entry = %{pairs[id] | market_data: Map.put(pairs[id].market_data, ex, emd)}
						Rebasing.Cache.clear()
						{:update, %Market{pairs: Map.put(pairs, id, market_entry)}, market_entry}
					true ->
						%ExchangeMarketData{
							last_price: old_lp,
							current_bid: old_cb,
							current_ask: old_ca,
							base_volume: old_bv
						} = pairs[id].market_data[ex]
						cond do
							old_lp === lp && old_cb === cb && old_ca === ca && old_bv === bv ->
								{:no_update, m, nil}
							true ->
								market_entry = %{pairs[id] | market_data: Map.put(pairs[id].market_data, ex, emd)}
								Rebasing.Cache.clear()
								{:update, %Market{pairs: Map.put(pairs, id, market_entry)}, market_entry}
						end
				end
		end
	end

	@doc """
	Adds all pairs of a given ExchangeMarket to the market.
	"""
	@spec add_exchange_market(Market.t, ExchangeMarket.t)
				:: {:no_update, Market.t, Pair.t} | {:update, Market.t, Pair.t}
	defp add_exchange_market(%Market{} = prev_market, %ExchangeMarket{market: m}) do
		Enum.reduce(m, {:no_update, prev_market, nil}, fn (p, {update_status, latest_market, latest_pair}) ->
			# Change update_status to :update if one or more pairs get updated.
			case add_pair(latest_market, p) do
				{:update, updated_market, updated_pair} -> {:update, updated_market, updated_pair}
				{:no_update, _updated_market, _updated_pair} -> {update_status, latest_market, latest_pair}
			end
		end)
	end

	@spec update_return({atom, Market.t, Pair.t}, map) :: {:noreply, map}
	defp update_return(add_result, state) do
		case add_result do
			{:no_update, _updated_market, _updated_pair} -> {:noreply, state}
			{:update, updated_market, updated_pair} ->
				updated_last_update = %LastUpdate{
					utc_time: NaiveDateTime.utc_now(),
					pair: updated_pair
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
