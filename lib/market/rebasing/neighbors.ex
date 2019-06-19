defmodule Dexaggregatex.Market.Rebasing.Neighbors do
	@moduledoc """
	Process maintaining neighbor relations between pairs in the market.
	"""
	use GenServer

	alias Dexaggregatex.Market.Structs.{Pair, Market}
	import Dexaggregatex.Market.Util

	@initial_state %{
		base_neighbors: %{},
		quote_neighbors: %{}
	}

	def start_link(_options) do
		GenServer.start_link(__MODULE__, nil, name: __MODULE__)
	end

	def get_base_neighbors(p_id) do
		GenServer.call(__MODULE__, {:get_base_neighbors, p_id})
	end

	def get_quote_neighbors(p_id) do
		GenServer.call(__MODULE__, {:get_quote_neighbors, p_id})
	end

	def add_pairs(pairs, %Market{} = m) do
		GenServer.cast(__MODULE__, {:add_pairs, pairs, m})
	end

	def remove_pairs(pairs) do
		GenServer.cast(__MODULE__, {:remove_pairs, pairs})
	end

	@impl true
	def init(_arg) do
		{:ok, @initial_state}
	end

	@impl true
	def handle_call({operation, p_id}, _from, %{base_neighbors: bn, quote_neighbors: qn} = state) do
		neighbors =
			case operation do
				:get_base_neighbors -> bn
				:get_quote_neighbors -> qn
			end
		case Map.has_key?(neighbors, p_id) do
			true -> {:reply, neighbors[p_id], state}
			false -> {:reply, [], state}
		end
	end

	@doc """
	Updates the neighbor relations with a given list of pairs.
	"""
	@impl true
	def handle_cast({:add_pairs, new_ps, %Market{pairs: pairs} = m},
				%{base_neighbors: old_bn, quote_neighbors: old_qn} = state) do
		new_ps_ids = Enum.map(new_ps, fn new_p -> pair_id(new_p) end)

		interm_bn =
			# Update all existing base neighbor relations with the new pair.
			Enum.reduce(old_bn, %{}, fn ({pair_id, bn}, acc1) ->
				%Pair{base_address: pim_ba} = pairs[pair_id]
				new_entry =
					Enum.reduce(new_ps_ids, bn, fn (new_p_id, acc2) ->
						%Pair{quote_address: new_qa} = pairs[new_p_id]
						case pim_ba == new_qa do
							true -> [new_p_id | acc2]
							false -> acc2
						end
					end)
				Map.put(acc1, pair_id, new_entry)
			end)
		new_bn =
			# Find all base neighbors to new pairs and add these to base neighbor relations.
			Enum.reduce(new_ps_ids, interm_bn, fn (new_p_id, acc) ->
				%Pair{base_address: new_ba} = pairs[new_p_id]
				new_bn_entry = Enum.reduce(pairs, [], fn ({pair_id, %Pair{quote_address: pim_qa} = pim}, acc) ->
					case pim_qa == new_ba do
						true -> [pair_id | acc]
						false -> acc
					end
				end)
				Map.put(acc, new_p_id, new_bn_entry)
			end)

		interm_qn =
			# Update all existing quote neighbor relations with the new pair.
			Enum.reduce(old_qn, %{}, fn ({pair_id, qn}, acc1) ->
				%Pair{quote_address: pim_qa} = pairs[pair_id]
				new_entry =
					Enum.reduce(new_ps_ids, qn, fn (new_p_id, acc2) ->
						%Pair{base_address: new_ba} = pairs[new_p_id]
						case pim_qa == new_ba do
							true -> [new_p_id | acc2]
							false -> acc2
						end
					end)
				Map.put(acc1, pair_id, new_entry)
			end)
		new_qn =
			# Find all quote neighbors to new pairs and add these to quote neighbor relations.
			Enum.reduce(new_ps_ids, interm_qn, fn (new_p_id, acc) ->
				%Pair{quote_address: new_qa} = pairs[new_p_id]
				new_qn_entry = Enum.reduce(pairs, [], fn ({pair_id, %Pair{base_address: pim_ba} = pim}, acc) ->
					case pim_ba == new_qa do
						true -> [pair_id | acc]
						false -> acc
					end
				end)
				Map.put(acc, new_p_id, new_qn_entry)
			end)

		{:noreply, %{state | base_neighbors: new_bn, quote_neighbors: new_qn}}
	end

	@doc """
	Removes given pairs out of all neighbor relations.
	"""
	@impl true
	def handle_cast({:remove_pairs, pairs}, %{base_neighbors: old_bn, quote_neighbors: old_qn} = state) do
		%{bn: new_bn, qn: new_qn} =
			Enum.reduce(pairs, %{bn: old_bn, qn: old_qn}, fn (%Pair{base_address: ba, quote_address: qa} = p, %{bn: bn_acc, qn: qn_acc}) ->
				p_id = pair_id(ba, qa)
				new_bn =
					Map.delete(bn_acc, p_id)
					|> Enum.map(fn {n_p_id, bn} -> {n_p_id, List.delete(bn, p_id)} end)
				new_qn =
					Map.delete(qn_acc, p_id)
					|> Enum.map(fn {n_p_id, qn} -> {n_p_id, List.delete(qn, p_id)} end)

				%{bn: new_bn, qn: new_qn}
			end)
		{:noreply, %{state | base_neighbors: new_bn, quote_neighbors: new_qn}}
	end

end
