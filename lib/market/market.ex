defmodule Dexaggregatex.Market do
  @moduledoc """
  Module maintaining the global market model.
  """
  use GenServer

  alias Dexaggregatex.Market.Rebasing
  alias Dexaggregatex.Market.Structs
  alias Dexaggregatex.Market.Structs.{RebasedMarket, Market, ExchangeMarketData, LastUpdate}
  alias Dexaggregatex.Market.Structs.Pair, as: MarketPair
  alias Dexaggregatex.MarketFetching.Structs.{ExchangeMarket, PairMarketData}
  alias Dexaggregatex.MarketFetching.Structs.Pair, as: MarketFetchingPair
  alias Dexaggregatex.API.Endpoint
  import Dexaggregatex.Market.Util

  @doc """
  Gets various data from this GenServer's state.
  """
  @spec get(atom | tuple) :: term | {:error, String.t}
  def get(what_to_get) do
    case what_to_get do
      :market ->
        GenServer.call(__MODULE__, :get_market)
      {:rebased_market, ra} ->
        GenServer.call(__MODULE__, {:get_rebased_market, ra})
      :exchanges ->
        GenServer.call(__MODULE__, :get_exchanges)
      :last_update ->
        GenServer.call(__MODULE__, :get_last_update)
      _ ->
        {:error, "Bad argument."}
    end
  end

  @doc """
  Updates the market with the given pair or exchange market.
  """
  @spec update(MarketFetchingPair.t | ExchangeMarket.t) :: :ok
  def update(pair_or_exchange_market) do
    Rebasing.Cache.clear()
    GenServer.cast(__MODULE__, {:update, pair_or_exchange_market})
  end

  def start_link(_options) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Initializes the market with empty structs.
  """
  @impl true
  @spec init(any) :: {:ok, map}
  def init(_initial_market) do
    {:ok, %{
      market: %Market{pairs: %{}},
      last_update: %LastUpdate{timestamp: nil, utc_time: nil, exchange: nil}
    }}
  end

  @doc """
  Returns the raw market, as maintained by this module.
  """
  @impl true
  @spec handle_call(atom, GenServer.from, map) :: {:reply, Structs.Market.t, map}
  def handle_call(:get_market, _from,  %{market: m} = state) do
    {:reply, m, state}
  end

  @doc """
  Returns the market rebased in a token with a specified rebase_address.
  """
  @impl true
  @spec handle_call({atom, String.t}, GenServer.from, map)
        :: {:reply, RebasedMarket.t, map}
  def handle_call({:get_rebased_market, ra}, _from, %{market: m} = state) do
    {:reply, Rebasing.rebase_market(ra, m, 3), state}
  end

  @doc """
  Returns a list of all the exchanges of which pairs are included in the market.
  """
  @impl true
  @spec handle_call(atom, GenServer.from, map)
        :: {:reply, [atom], map}
  def handle_call(:get_exchanges, _from, %{market: m} = state) do
    {:reply, exchanges_in_market(m), state}
  end


  @doc """
  Returns a data structure containing data about the last market update.
  """
  @impl true
  @spec handle_call(atom, GenServer.from, map)
        :: {:reply, LastUpdate.t, map}
  def handle_call(:get_last_update, _from, %{last_update: lu} = state) do
    {:reply, lu, state}
  end

  @spec exchanges_in_market(Structs.Market.t) :: MapSet.t(atom)
  defp exchanges_in_market(%Structs.Market{pairs: pairs}) do
    Enum.reduce(pairs, MapSet.new(), fn ({_k, p}, acc1) ->
      Enum.reduce(p.market_data, acc1, fn {exchange, _emd}, acc2->
        MapSet.put(acc2, exchange)
      end)
    end)
  end

  @impl true
  @spec handle_cast({atom, ExchangeMarket.t}, map) :: {:noreply, map}
  def handle_cast({:update, %ExchangeMarket{} = em}, %{market: m} = state) do
    %ExchangeMarket{exchange: exchange} = em
    add_exchange_market_result = add_exchange_market(m, em)
    update_reply(add_exchange_market_result, exchange, state)
  end

  @impl true
  @spec handle_cast({atom, MarketFetchingPair.t}, map) :: {:noreply, map}
  def handle_cast({:update, %MarketFetchingPair{} = p}, %{market: m} = state) do
    %MarketFetchingPair{market_data: %PairMarketData{exchange: exchange}} = p
    add_pair_result = add_pair(m, p)
    update_reply(add_pair_result, exchange, state)
  end

  @spec update_reply({atom, Structs.Market.t}, atom, map) :: {:noreply, map}
  defp update_reply(add_result, exchange, state) do
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

  @doc """
  Adds a single pair to the market.
  """
  @spec add_pair(Structs.Market.t, MarketFetchingPair.t)
        :: {:no_update, Structs.Market.t} | {:update, Structs.Market.t}
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
  @spec add_exchange_market(Structs.Market.t, ExchangeMarket.t)
        :: {:no_update, Structs.Market.t} | {:update, Structs.Market.t}
  defp add_exchange_market(%Market{} = prev_market, %ExchangeMarket{market: m}) do
    Enum.reduce(m, {:no_update, prev_market}, fn (p, {_update_status, market_acc}) ->
      add_pair(market_acc, p)
    end)
  end
end
