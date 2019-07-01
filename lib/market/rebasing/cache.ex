defmodule Dexaggregatex.Market.Rebasing.Cache do
  defmodule State do
    @moduledoc """
    Data structure representing a Rebasing.Cache state.
    """
    @enforce_keys [:rebase_market]
    defstruct [:rebase_market]

    @typedoc """
    * rebase_market: data structure representing all cached function calls to rebase_market.
    """
    @type t :: %__MODULE__{rebase_market: map}
  end

  @moduledoc """
  Simple cache to avoid recomputation during rebasing.
  """
  use GenServer

  @spec start_link(any) :: GenServer.on_start()
  def start_link(_options), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @type function_call :: {:rebase_market, {String.t(), integer}}
  @spec get(function_call) :: any
  def get(function_call), do: GenServer.call(__MODULE__, {:get, function_call})

  @spec add(function_call, any) :: :ok
  def add(function_call, result), do: GenServer.cast(__MODULE__, {:add, function_call, result})

  @spec clear() :: :ok
  def clear(), do: GenServer.cast(__MODULE__, :clear)

  @spec init(any) :: {:ok, State.t()}
  @impl true
  def init(_arg), do: {:ok, %State{rebase_market: %{}}}

  @typep get_return :: {:found, any} | {:not_found, nil}
  @spec handle_call({:get, function_call}, GenServer.from(), State.t()) ::
          {:reply, get_return, State.t()}
  @impl true
  def handle_call({:get, {f, args}}, _from, state) do
    rv =
      case Map.has_key?(Map.get(state, f), args),
        do:
          (
            true -> {:found, Map.get(state, f)[args]}
            false -> {:not_found, nil}
          )

    {:reply, rv, state}
  end

  @spec handle_cast({:add, function_call, any}, State.t()) :: {:noreply, State.t()}
  @impl true
  def handle_cast({:add, {f, args}, res}, state) do
    entry = Map.put(Map.get(state, f), args, res)
    {:noreply, Map.put(state, f, entry)}
  end

  @spec handle_cast(:clear, State.t()) :: {:noreply, State.t()}
  @impl true
  def handle_cast(:clear, _state), do: {:noreply, %State{rebase_market: %{}}}
end
