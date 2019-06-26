defmodule Dexaggregatex.Market.CheapestPaths do
	@moduledoc """
	Functions for finding cheapest paths from token to token.
	"""
	alias Dexaggregatex.Market.Structs.{Pair, RebasedMarket, ExchangeMarketData}
	alias Dexaggregatex.Market.Rebasing.Neighbors
	import Dexaggregatex.Market.Util

	def cheapest_paths(%RebasedMarket{} = rm, from_address, to_address, amount) do
		#Calculate multiple cheapest paths here.
	end

	def cheapest_path(%RebasedMarket{} = rm, from_address, to_address) do
		Enum.reduce(pairs_with_qa(rm, from_address), %{cost: :infinity, path: []}, fn ({_k, p}, acc) ->
			cp = cheapest_path(rm, p, to_address)
			case cp.cost < acc.cost, do: (true -> cp; false -> acc)
		end)
	end

	def cheapest_path(%RebasedMarket{pairs: pairs} = rm, %Pair{} = initial_p, to_address) do
		initial_p_id = pair_id(initial_p)
		initial_state = %{current_cost: initial_p.market_data.current_bid, current_p_id: initial_p_id}
		initial_costs =
			Enum.reduce(pairs, %{}, fn ({p_id, _p}, acc) ->
				v = case initial_state.current_p_id == p_id, do: (true -> 0; false -> :infinity)
				Map.put(acc, p_id, %{cost: v, prev_p_id: nil})
			end)
		try_expand_path(initial_state, rm, to_address, initial_costs, MapSet.new(initial_p_id))
	end

	defp try_expand_path(%{current_cost: current_cost, current_p_id: current_p_id} = state, %RebasedMarket{pairs: pairs} = rm, to_address, costs, visited_pairs) do
		case Enum.any?(pairs_with_ba(rm, to_address), fn {k, _p} -> Enum.member?(visited_pairs, k) end) do
			true ->
				path = find_path([current_p_id], costs)
				%{cost: current_cost, path: path}
			false ->
				next_p_id =
					Enum.reject(pairs, fn {k, _p} -> Enum.member?(visited_pairs, k) end)
					|> Enum.min_by(fn {k, _p} -> costs[k].cost end)
				expand_path(%{state | current_p_id: next_p_id}, rm, to_address, costs, visited_pairs)
		end
	end

	defp find_path([last_p_id | _] = path, costs) do
		case costs[last_p_id].prev_p_id do
			nil -> path
			not_nil -> find_path([not_nil | path], costs)
		end
	end

	defp expand_path(%{current_cost: current_cost, current_path: [current_p_id | _] = current_path}, %RebasedMarket{pairs: pairs} = rm, to_address, costs, visited_pairs) do
		new_costs =
			Neighbors.get_neighbors(:base, current_p_id)
			|> Enum.filter(fn n_id -> !Enum.member?(visited_pairs, n_id) end)
			|> Enum.reduce(costs, fn (n_id, costs_acc) ->
				%Pair{market_data: %ExchangeMarketData{current_bid: n_cb}} = pairs[n_id]
				case current_cost * n_cb < costs_acc[n_id].cost do
					true -> Map.put(costs_acc, n_id, %{cost: current_cost * n_cb, prev_p_id: current_p_id})
					false -> costs_acc
				end
			end)
		new_visited_pairs = MapSet.put(visited_pairs, current_p_id)
		try_expand_path(%{current_cost: current_cost, current_path: [current_p_id | current_path]}, rm, to_address, new_costs, new_visited_pairs)
	end

	defp pairs_with_qa(%RebasedMarket{pairs: pairs} = _rm, qa) do
		Enum.reduce(pairs, %{}, fn ({k, %Pair{quote_address: p_qa} = p}, acc) ->
			case p_qa == qa, do: (true -> Map.put(acc, k, p); false -> acc)
		end)
	end

	defp pairs_with_ba(%RebasedMarket{pairs: pairs} = _rm, ba) do
		Enum.reduce(pairs, %{}, fn ({k, %Pair{base_address: p_ba} = p}, acc) ->
			case p_ba == ba, do: (true -> Map.put(acc, k, p); false -> acc)
		end)
	end

end
