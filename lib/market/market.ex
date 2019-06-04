defmodule Market do
  @moduledoc """
    Module maintaining the global market model.
  """
  use GenServer

  import Market.Util

  @doc """
    Gets various data from this module's state.
  """
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
        nil
    end
  end

  @doc """
    Updates the market with the given pair or exchange market.
  """
  def update(pair_or_exchange_market) do
    Rebasing.Cache.clear()
    GenServer.cast(__MODULE__, {:update, pair_or_exchange_market})
  end

  def start_link(_options) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_initial_market) do
    {:ok, %{market: %{}, last_update: nil}}
  end

  @doc """
    Returns the raw market.
  """
  @impl true
  def handle_call(:get_market, _from,  %{market: m} = state) do
    {:reply, m, state}
  end

  @doc """
    Returns the market rebased in a token with a specified rebase_address.
  """
  @impl true
  def handle_call({:get_rebased_market, ra}, _from, %{market: m} = state) do
    {:reply, Market.Rebasing.rebase_market(ra, m, 3), state}
  end

  @doc """
    Returns a list of all the exchanges of which pairs are included in the market.
  """
  @impl true
  def handle_call(:get_exchanges, _from, %{market: m} = state) do
    {:reply, exchanges_in_market(m), state}
  end


  @doc """
    Returns a data structure containing data about the last market update.
  """
  @impl true
  def handle_call(:get_last_update, _from, %{last_update: lu} = state) do
    {:reply, lu, state}
  end

  def exchanges_in_market(market) do
    Enum.reduce(market, MapSet.new(), fn ({_k, p}, acc1) ->
      Enum.reduce(p.market_data, acc1, fn {exchange, _emd}, acc2->
        MapSet.put(acc2, exchange)
      end)
    end)
  end

  @impl true
  def handle_cast({:update, %MarketFetching.ExchangeMarket{} = em}, %{market: m} = state) do
    %MarketFetching.ExchangeMarket{exchange: exchange} = em
    updated_market = add_exchange_market(m, em)
    update_reply(updated_market, exchange, state)
  end

  @impl true
  def handle_cast({:update, %MarketFetching.Pair{} = p}, %{market: m} = state) do
    %MarketFetching.Pair{market_data: %MarketFetching.PairMarketData{exchange: exchange}} = p
    updated_market = add_pair(m, p)
    update_reply(updated_market, exchange, state)
  end

  defp update_reply(updated_market, exchange, state) do
    updated_last_update = %Market.LastUpdate{
      timestamp: :os.system_time(),
      exchange: exchange
    }
    Supervisor.start_link([
      {Task, fn -> Absinthe.Subscription.publish(API.Endpoint, updated_market, [updated_market: "*", updated_rebased_market: "*"]) end}
    ], strategy: :one_for_one)
    {:noreply, %{state | market: updated_market, last_update: updated_last_update}}
  end


  @doc """
    Adds a single pair to the market.
  """
  defp add_pair(pairs, %MarketFetching.Pair{} = p) do
    %MarketFetching.Pair{
      base_address: ba,
      quote_address: qa,
      base_symbol: bs,
      quote_symbol: qs,
      market_data: %MarketFetching.PairMarketData{
        exchange: ex,
        last_price: lp,
        current_bid: cb,
        current_ask: ca,
        base_volume: bv,
      }
    } = p

    id = pair_id(ba, qa)
    emd = %Market.ExchangeMarketData{
      last_price: lp,
      current_bid: cb,
      current_ask: ca,
      base_volume: bv,
    }

    market_entry =
      case Map.has_key?(pairs, id) do
        false ->
          %Market.Pair{
            base_address: ba,
            quote_address: qa,
            base_symbol: bs,
            quote_symbol: qs,
            market_data: %{
              ex => emd
            }
          }
        true ->
          %{pairs[id] | market_data: Map.put(pairs[id].market_data, ex, emd)}
      end

    Map.put(pairs, id, market_entry)
  end

  @doc """
    Adds all pairs of a given ExchangeMarket to the market.
  """
  defp add_exchange_market(prev_market, %MarketFetching.ExchangeMarket{market: m}) do
    Enum.reduce(m, prev_market, fn (p, acc) ->
      add_pair(acc, p)
    end)
  end
end
