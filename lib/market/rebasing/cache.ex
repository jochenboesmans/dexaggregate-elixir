defmodule Dexaggregatex.Market.Rebasing.Cache do
  @moduledoc """
  Simple cache to avoid recomputation during rebasing.
  """
  use GenServer

  @initial_state %{
    rebase_market: %{},
    rebase_rate: %{},
    combined_volume_across_exchanges: %{},
    deeply_rebase_rate: %{},
    expand_path_from_base: %{},
    expand_path_from_quote: %{},
    volume_weighted_spread_average: %{}
  }

  def start_link(_options) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get(args) do
    GenServer.call(__MODULE__, {:get_from_cache, args})
  end

  def add(args) do
    GenServer.cast(__MODULE__, {:add_to_cache, args})
  end

  def clear() do
    GenServer.cast(__MODULE__, :clear)
  end

  @impl true
  def init(_arg) do
    {:ok, @initial_state}
  end

  @impl true
  def handle_call({:get_from_cache, {function, args}}, _from, state) do
    case Map.has_key?(state[function], args) do
      true ->
        {:reply, {:found, state[function][args]}, state}
      false ->
        {:reply, {:not_found, nil}, state}
    end
  end

  @impl true
  def handle_cast({:add_to_cache, {function, args, res}}, state) do
    entry = Map.put(state[function], args, res)
    {:noreply, Map.put(state, function, entry)}
  end

  @impl true
  def handle_cast(:clear, _state) do
    {:noreply, @initial_state}
  end
end
