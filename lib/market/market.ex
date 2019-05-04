defmodule Market do
  @moduledoc """
    GenServer maintaining the global market.
  """

  use GenServer
  alias MarketFetching.ExchangeMarket, as: ExchangeMarket
  alias Market.Rebasing, as: Rebasing
  import Market.Util

  def get(atom) do
    case atom do
      :market ->
        GenServer.call(__MODULE__, :get_market)
      :rebased_market ->
        GenServer.call(__MODULE__, :get_rebased_market)
      :exchanges ->
        GenServer.call(__MODULE__, :get_exchanges)
      _ ->
        nil
    end

  end

  def update(exchange_market) do
    GenServer.cast(__MODULE__, {:update, exchange_market})
  end

  def start_link(_options) do
    children = []
    options = [
      strategy: :one_for_one,
      name: __MODULE__
    ]
    GenServer.start_link(__MODULE__, children, options)
  end

  @impl true
  def init(_initial_market) do
    {:ok, %{market: %{}, rebased_market: %{}}}
  end

  @impl true
  def handle_call(:get_market, _from, %{market: m} = state) do
    {:reply, format_market(m), state}
  end

  @impl true
  def handle_call(:get_rebased_market, _from, %{rebased_market: rm} = state) do
    {:reply, format_market(rm), state}
  end

  @impl true
  def handle_call(:get_exchanges, _from, %{market: m} = state) do
    {:reply, exchanges_in_market(m), state}
  end

  defp format_market(m) do
    Map.values(m)
    |> Enum.sort_by(&combined_volume_across_exchanges/1, &>=/2)
  end

  defp combined_volume_across_exchanges(p) do
    Enum.reduce(p.market_data, 0, fn ({_exchange, emd}, acc) ->
      acc + emd.base_volume
    end)
  end

  def exchanges_in_market(market) do
    Enum.reduce(market, MapSet.new(), fn ({_k, p}, acc1) ->
      Enum.reduce(p.market_data, acc1, fn {exchange, _emd}, acc2->
        MapSet.put(acc2, exchange)
      end)
    end)
  end

  @impl true
  def handle_cast({:update, %ExchangeMarket{} = em}, prev_state) do
    {:noreply, merge(prev_state, em)}
  end

  @impl true
  def handle_cast({:update, %MarketFetching.Pair{} = p}, prev_state) do
    {:noreply, merge(prev_state, p)}
  end

  def add_pair(m, %MarketFetching.Pair{} = p) do
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
        quote_volume: qv
      }
    } = p

    id = pair_id(ba, qa)
    emd = %Market.ExchangeMarketData{
      last_price: lp,
      current_bid: cb,
      current_ask: ca,
      base_volume: bv,
      quote_volume: qv
    }

    market_entry =
      case Map.has_key?(m, id) do
        false ->
          %Market.Pair{
            base_symbol: bs,
            base_address: ba,
            quote_address: qa,
            quote_symbol: qs,
            market_data: %{
              ex => emd
            }
          }
        true ->
          %{m[id] | market_data: Map.put(m[id].market_data, ex, emd)}
      end

    Map.put(m, id, market_entry)
  end

  @dai_address "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359
"
  def merge(%{market: prev_market}, %MarketFetching.Pair{} = p) do
    market = add_pair(prev_market, p)

    rebased_market = Rebasing.rebase_market(@dai_address, market, 4)

    %{market: market, rebased_market: rebased_market}
  end

  def merge(%{market: prev_market}, %ExchangeMarket{market: m}) do
    market = Enum.reduce(m, prev_market, fn (p, acc) ->
      add_pair(acc, p)
    end)

    rebased_market = Rebasing.rebase_market(@dai_address, market, 4)

    %{market: market, rebased_market: rebased_market}
  end
end
