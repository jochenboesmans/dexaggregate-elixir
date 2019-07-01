defmodule Dexaggregatex.Market.Rebasing.Neighbors do
  defmodule State do
    @moduledoc """
    Data structure representing a Rebasing.Neighbors state.
    """
    @enforce_keys [:base_neighbors, :quote_neighbors]
    defstruct [:base_neighbors, :quote_neighbors]

    @typedoc """
    * base_neighbors: data structure representing all base neighboring pair relations in the market.
    * quote_neighbors: data structure representing all quote neighboring pair relations in the market.
    """
    @type neighbors :: %{optional(String.t()) => [String.t()]}
    @type t :: %__MODULE__{base_neighbors: neighbors, quote_neighbors: neighbors}
  end

  @moduledoc """
  Stateful process maintaining neighbor relations between pairs in the market.
  """
  use GenServer

  alias Dexaggregatex.Market.Rebasing.Neighbors.State
  alias Dexaggregatex.Market.Structs.{Pair, Market}
  import Dexaggregatex.Market.Util

  @spec start_link(any) :: GenServer.on_start()
  def start_link(_options), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @type direction :: :base | :quote
  @spec get_neighbors(direction, String.t()) :: [String.t()]
  def get_neighbors(direction, p_id),
    do: GenServer.call(__MODULE__, {:get_neighbors, direction, p_id})

  @spec add_pairs([Pair.t()], Market.t()) :: :ok
  def add_pairs(pairs, %Market{} = m), do: GenServer.cast(__MODULE__, {:add_pairs, pairs, m})

  @spec remove_pairs([Pair.t()]) :: :ok
  def remove_pairs(pairs), do: GenServer.cast(__MODULE__, {:remove_pairs, pairs})

  @spec init(any) :: {:ok, State.t()}
  @impl true
  def init(_arg), do: {:ok, %State{base_neighbors: %{}, quote_neighbors: %{}}}

  @typep call_operation :: {:get_neighbors, :base | :quote, String.t()}
  @spec handle_call(call_operation, GenServer.from(), State.t()) ::
          {:reply, State.neighbors(), State.t()}
  @impl true
  def handle_call(
        {:get_neighbors, direction, p_id},
        _from,
        %State{base_neighbors: bn, quote_neighbors: qn} = state
      ) do
    n =
      case direction do
        :base -> bn
        :quote -> qn
      end
      |> Map.get(p_id, [])

    {:reply, n, state}
  end

  @doc """
  Updates the neighbor relations based on a list of pairs new to the market.
  """
  @spec handle_cast({:add_pairs, [Pair.t()], Market.t()}, State.t()) :: {:noreply, State.t()}
  @impl true
  def handle_cast(
        {:add_pairs, new_ps, %Market{pairs: pairs} = m},
        %State{base_neighbors: old_bn, quote_neighbors: old_qn} = state
      ) do
    new_ps_ids = Enum.map(new_ps, fn new_p -> pair_id(new_p) end)

    # Update all existing base neighbor relations with the new pair.
    # Enum.reduce is used instead of Enum.map |> Enum.into(%{}) because of performance.
    interm_bn =
      Enum.reduce(old_bn, %{}, fn {pair_id, bn}, acc1 ->
        %Pair{base_address: pim_ba} = pairs[pair_id]

        new_entry =
          Enum.reduce(new_ps_ids, bn, fn new_p_id, acc2 ->
            # Add a relation for all new pairs with a quote_address matching the original pair's base_address.
            %Pair{quote_address: new_qa} = pairs[new_p_id]

            case pim_ba == new_qa,
              do:
                (
                  true -> [new_p_id | acc2]
                  false -> acc2
                )
          end)

        Map.put(acc1, pair_id, new_entry)
      end)

    # Find all base neighbors to new pairs and add these relations to the intermediate base neighbor relations.
    new_bn =
      Enum.reduce(new_ps_ids, interm_bn, fn new_p_id, acc ->
        %Pair{base_address: new_ba} = pairs[new_p_id]

        new_bn_entry =
          Enum.reduce(pairs, [], fn {pair_id, %Pair{quote_address: pim_qa}}, acc ->
            case pim_qa == new_ba,
              do:
                (
                  true -> [pair_id | acc]
                  false -> acc
                )
          end)

        Map.put(acc, new_p_id, new_bn_entry)
      end)

    # Update all existing quote neighbor relations with the new pair.
    # Enum.reduce is used instead of Enum.map |> Enum.into(%{}) because of performance.
    interm_qn =
      Enum.reduce(old_qn, %{}, fn {pair_id, qn}, acc1 ->
        %Pair{quote_address: pim_qa} = pairs[pair_id]

        # Add a relation for all new pairs with a base_address matching the original pair's quote_address.
        new_entry =
          Enum.reduce(new_ps_ids, qn, fn new_p_id, acc2 ->
            %Pair{base_address: new_ba} = pairs[new_p_id]

            case pim_qa == new_ba,
              do:
                (
                  true -> [new_p_id | acc2]
                  false -> acc2
                )
          end)

        Map.put(acc1, pair_id, new_entry)
      end)

    # Find all quote neighbors to new pairs and add these to quote neighbor relations.
    new_qn =
      Enum.reduce(new_ps_ids, interm_qn, fn new_p_id, acc ->
        %Pair{quote_address: new_qa} = pairs[new_p_id]

        new_qn_entry =
          Enum.reduce(pairs, [], fn {pair_id, %Pair{base_address: pim_ba}}, acc ->
            case pim_ba == new_qa,
              do:
                (
                  true -> [pair_id | acc]
                  false -> acc
                )
          end)

        Map.put(acc, new_p_id, new_qn_entry)
      end)

    {:noreply, %State{base_neighbors: new_bn, quote_neighbors: new_qn}}
  end

  @doc """
  Removes given pairs out of all neighbor relations.
  """
  @spec handle_cast({:remove_pairs, [Pair.t()]}, State.t()) :: {:noreply, State.t()}
  @impl true
  def handle_cast(
        {:remove_pairs, pairs},
        %State{base_neighbors: old_bn, quote_neighbors: old_qn} = state
      ) do
    updated_state =
      Enum.reduce(
        pairs,
        %State{base_neighbors: old_bn, quote_neighbors: old_qn} = state,
        fn %Pair{base_address: ba, quote_address: qa},
           %State{base_neighbors: bn_acc, quote_neighbors: qn_acc} ->
          p_id = pair_id(ba, qa)
          # Delete deleted pair's entry.
          new_bn =
            Map.delete(bn_acc, p_id)
            # Delete pair from base neighbor relations of other pairs.
            |> Enum.reduce(%{}, fn {n_p_id, bn}, acc ->
              Map.put(acc, n_p_id, List.delete(bn, p_id))
            end)

          # Delete deleted pair's entry.
          new_qn =
            Map.delete(qn_acc, p_id)
            # Delete pair from quote neighbor relations of other pairs.
            |> Enum.reduce(%{}, fn {n_p_id, qn}, acc ->
              Map.put(acc, n_p_id, List.delete(qn, p_id))
            end)

          %State{base_neighbors: new_bn, quote_neighbors: new_qn}
        end
      )

    {:noreply, updated_state}
  end
end
