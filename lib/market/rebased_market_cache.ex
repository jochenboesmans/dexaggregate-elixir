defmodule RebasedMarketCache do
  @moduledoc false
  use GenServer

  def start_link(_options) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get(ra) do
    GenServer.call(__MODULE__, {:get_from_cache, ra})
  end

  def add(ra, rm) do
    GenServer.cast(__MODULE__, {:add_to_cache, ra, rm})
  end

  def clear() do
    GenServer.cast(__MODULE__, :clear)
  end

  @impl true
  def init(_arg) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get_from_cache, ra}, _from, state) do
    case Map.has_key?(state, ra) do
      true ->
        {:reply, {:found, state[ra]}, state}
      false ->
        {:reply, {:not_found, nil}, state}
    end
  end

  @impl true
  def handle_cast({:add_to_cache, ra, rm}, state) do
    {:noreply, Map.put(state, ra, rm)}
  end

  @impl true
  def handle_cast(:clear, _state) do
    {:noreply, %{}}
  end
end
