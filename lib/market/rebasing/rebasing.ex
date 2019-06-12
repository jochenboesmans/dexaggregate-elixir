defmodule Dexaggregatex.Market.Rebasing do
	@moduledoc """
	Logic for rebasing pairs of a market to a token, denominating all rates in this token.
	"""

	import Dexaggregatex.Market.Util
	alias Dexaggregatex.Market.Structs
	alias Dexaggregatex.Market.Structs.{ExchangeMarketData, Pair, RebasedMarket}
	alias Dexaggregatex.Market.Rebasing

	# Makes sure private functions are testable.
	@compile if Mix.env == :test, do: :export_all

	@doc """
		Rebases all pairs in a given market to a token with a given rebase_address.
	"""
	def rebase_market(rebase_address, %Structs.Market{pairs: pairs}, max_depth) do
		rebased_pairs =
			case Rebasing.Cache.get({:rebase_market, {rebase_address, max_depth}}) do
				{:found, cached_market} ->
					cached_market
				{:not_found, _} ->
					created_tasks = Enum.map(pairs, fn ({pair_id, p}) ->
						{pair_id, Task.async(fn -> rebase_pair([p, rebase_address, pairs, max_depth]) end)}
					end)

					rebased_market = Enum.reduce(created_tasks, %{}, fn ({k, p}, acc) ->
						result = Task.await(p, 15_000)
						Map.put(acc, k, result)
					end)

					Rebasing.Cache.add({:rebase_market, {rebase_address, max_depth}, rebased_market})
					rebased_market
			end

		%RebasedMarket{
			pairs: rebased_pairs,
			base_address: rebase_address,
		}
	end

  def rebase_pair([p, rebase_address, market, max_depth]) do
    %{p | market_data: rebase_market_data(p, rebase_address, market, max_depth)}
  end

	@doc """
		Rebases all market data for a given pair to a token with a given rebase_address as the token's address.
	"""
	def rebase_market_data(%Pair{market_data: pmd} = p, rebase_address, market, max_depth) do
		Enum.reduce(pmd, %{}, fn ({exchange_id, emd}, acc) ->
			rebased_emd = %{emd |
				last_price: deeply_rebase_rate(emd.last_price, p, rebase_address, market, max_depth),
				current_bid: deeply_rebase_rate(emd.current_bid, p, rebase_address, market, max_depth),
				current_ask: deeply_rebase_rate(emd.current_ask, p, rebase_address, market, max_depth),
				base_volume: deeply_rebase_rate(emd.base_volume, p, rebase_address, market, max_depth),
			}
			Map.put(acc, exchange_id, rebased_emd)
		end)
	end

	@doc """
		Rebases a given rate of a pair based in a token with a given base_address to a token with a given rebase_address.

		## Examples
			iex> dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
			iex> eth_address = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
			iex> sample_market = %{
			...>  Dexaggregatex.Market.Util.pair_id(dai_address, eth_address) =>
			...>	%Dexaggregatex.Market.Structs.Pair{
			...>    base_symbol: "DAI",
			...>		quote_symbol: "ETH",
			...>		quote_address: eth_address,
			...>		base_address: dai_address,
			...>		market_data: %{:oasis =>
			...>      %Dexaggregatex.Market.Structs.ExchangeMarketData{
			...>			  last_price: 200,
			...>			  current_bid: 195,
			...>			  current_ask: 205,
			...>			  base_volume: 100_000,
			...>		  }
			...>	  }
			...>  }
			...> }
			iex> Dexaggregatex.Market.Rebasing.rebase_rate(100, dai_address, eth_address, sample_market)
			20_000.0
	"""
	def rebase_rate(rate, rebase_address, base_address, market) do
		case Rebasing.Cache.get({:rebase_rate, {rate, rebase_address, base_address}}) do
			{:found, cached_result} ->
				cached_result
			{:not_found, _} ->
				result =
					case rebase_address == base_address do
						true ->
							rate
						false ->
							rebase_pair_id = pair_id(rebase_address, base_address)
							case Map.has_key?(market, rebase_pair_id) do
								true ->
									rate * volume_weighted_spread_average(market[rebase_pair_id], market)
								false ->
									0
							end
					end

				Rebasing.Cache.add({:rebase_rate, {rate, rebase_address, base_address}, result})
				result
		end
	end

	@doc """
		Calculates the combined volume across all exchanges of a given token in the market,
		denominated in the base token of the market pair.

		## Examples
			iex> dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
			iex> eth_address = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
			iex> dai_eth = %Dexaggregatex.Market.Structs.Pair{
			...>    base_symbol: "DAI",
			...>		quote_symbol: "ETH",
			...>		quote_address: eth_address,
			...>		base_address: dai_address,
			...>		market_data: %{
			...>			:oasis => %Dexaggregatex.Market.Structs.ExchangeMarketData{
			...>			  last_price: 0,
			...>			  current_bid: 0,
			...>			  current_ask: 0,
			...>			  base_volume: 100,
			...>		  },
			...>			:kyber => %Dexaggregatex.Market.Structs.ExchangeMarketData{
			...>				last_price: 0,
			...>				current_bid: 0,
			...>				current_ask: 0,
			...>				base_volume: 150,
			...>			}
			...>	  }
			...>  }
			iex> sample_market = %{Dexaggregatex.Market.Util.pair_id(dai_eth) => dai_eth}
			iex> Dexaggregatex.Market.Rebasing.combined_volume_across_exchanges(dai_eth, sample_market)
			250

	"""
	def combined_volume_across_exchanges(p, market) do
		case Rebasing.Cache.get({:combined_volume_across_exchanges, p}) do
			{:found, cached_result} ->
				cached_result
			{:not_found, _} ->
				%Pair{market_data: pmd} = market[pair_id(p)]
				result = Enum.reduce(pmd, 0, fn ({_exchange_id, %ExchangeMarketData{base_volume: bv}}, sum) -> sum + bv end)

				Rebasing.Cache.add({:combined_volume_across_exchanges, p, result})
				result
		end
	end

	@doc """
		Deeply rebases a given rate of a given token in the market as the volume-weighted rate of all possible paths
		from the given base_address to the given rebase_address with a maximum path length of 2 rebases.
	"""
	def deeply_rebase_rate(rate, original_pair, rebase_address, market, max_depth) do
		case Rebasing.Cache.get({:deeply_rebase_rate, {rate, original_pair, rebase_address, max_depth}}) do
			{:found, cached_result} ->
				cached_result
			{:not_found, _} ->
				%{combined_volume: cv, volume_weighted_sum: vws} =
					sums_for_deep_rebasing(rate, original_pair, rebase_address, market, max_depth)

				result =
					case cv do
						0 ->
							0
						0.0 ->
							0.0
						_ ->
							vws / cv
					end

				Rebasing.Cache.add({:deeply_rebase_rate, {rate, original_pair, rebase_address, max_depth}, result})
				result
		end
	end

	@doc """
	Calculates the values that determine a volume-weighted rate.
	"""
	defp sums_for_deep_rebasing(rate, original_pair, rebase_address, pairs, max_depth) do
		%Pair{base_address: orig_ba, quote_address: orig_qa} = original_pair
		base_rebase_paths = try_expand_path_from_base([{orig_qa, orig_ba}], rebase_address, quote_neighbors(pairs), max_depth)
		quote_rebase_paths = try_expand_path_from_quote([{orig_qa, orig_ba}], rebase_address, base_neighbors(pairs), max_depth)

		r =
			Enum.reduce(base_rebase_paths, %{combined_volume: 0, volume_weighted_sum: 0}, fn (base_rebase_path, sums) ->
				base_update_sums(sums, base_rebase_path, rate, pairs, rebase_address)
			end)
		Enum.reduce(quote_rebase_paths, r, fn (quote_rebase_path, sums) ->
			quote_update_sums(sums, quote_rebase_path, rate, pairs, rebase_address)
		end)
	end

	@doc """
	Index to reduce complexity of searching for quote_address neighbors.
	"""
	def quote_neighbors(pairs) do
		Enum.reduce(pairs, %{}, fn ({_id, %Pair{quote_address: qa, base_address: ba}}, acc) ->
			{_old_value, updated_map} = Map.get_and_update(acc, qa, fn v ->
				case v do
					nil -> {v, [ba]}
					not_nil -> {v, [ba | not_nil]}
				end
			end)
			updated_map
		end)
	end

	@doc """
	Index to reduce complexity of searching for base_address neighbors.
	"""
	def base_neighbors(pairs) do
		Enum.reduce(pairs, %{}, fn ({_id, %Pair{quote_address: qa, base_address: ba}}, acc) ->
			{_old_value, updated_map} = Map.get_and_update(acc, ba, fn v ->
				case v do
					nil -> {v, [qa]}
					not_nil -> {v, [qa | not_nil]}
				end
			end)
			updated_map
		end)
	end

	@doc """
	Updates the given volume-weighted-rate-determining sums based on the given rebase_path.
	"""
	defp base_update_sums(sums, base_rebase_path, original_rate, pairs, rebase_address) do
		max_i = Enum.count(base_rebase_path) - 1

		# Rebase the original_rate for every pair of the rebase_path.
		rebased_rate =
			Enum.with_index(base_rebase_path)
			# Iterate through the rebase_path starting from the original_pair, going to the pair based in rebase_address,
			#	rebasing the original_rate to the base_address of all pairs that aren't the original one.
			|> List.foldr(original_rate,
				 fn ({{rp_qa, rp_ba}, i}, acc) ->
					 case i === max_i do
						 true ->
							 # Keep original_rate since it's already based in the original pair's base address.
							 acc
						 false ->
							 # Rebase the rate currently based in this pair's quote address (previous pair's base address)
							 # to this pair's base address.
							 rebase_rate(acc, rp_ba, rp_qa, pairs)
					 end
				 end)

		# Calculate each involved pair's combined volume and rebase it in the base address of the ultimate rebase pair.
		# This rebase_path's weight is the average volume of all involved pairs.
		weight =
			Enum.reduce(Enum.with_index(base_rebase_path), 0, fn ({{rp_qa, rp_ba} = _rebase_pair, i}, sum) ->
				cond do
          # Exclude volumes of start pair.
          i === max_i ->
            sum
          # Include volumes of all other pairs.
          true ->
            rebased_phase_volume =
              combined_volume_across_exchanges(pairs[pair_id(rp_ba, rp_qa)], pairs)
              |> rebase_rate(rebase_address, rp_ba, pairs)
            sum + rebased_phase_volume
        end

			end) / Enum.count(base_rebase_path)

		%{sums |
			volume_weighted_sum: sums.volume_weighted_sum + (weight * rebased_rate),
			combined_volume: sums.combined_volume + weight
		}
	end

	@doc """
	Updates the given volume-weighted-rate-determining sums based on the given rebase_path.
	"""
	defp quote_update_sums(sums, quote_rebase_path, original_rate, pairs, rebase_address) do
		max_i = Enum.count(quote_rebase_path) - 1

		# Rebase the original_rate for every pair of the rebase_path.
		rebased_rate =
			Enum.with_index(quote_rebase_path)
			# Iterate through the rebase_path starting from the original_pair, going to the pair based in rebase_address,
			#	rebasing the original_rate to the base_address of all pairs that aren't the last one.
			|> List.foldr(original_rate,
					 fn ({{rp_qa, rp_ba}, i}, acc) ->
						 case i === 0 do
							 true ->
								 # Keep rate since it's already based in the rebase address.
								 acc
							 false ->
								 # Rebase the rate currently based in this pair's base address
								 # to this pair's quote address (next pair's base address).
								 rebase_rate(acc, rp_qa, rp_ba, pairs)
						 end
					 end)

		# Calculate each involved pair's combined volume and rebase it in the base address of the ultimate rebase pair.
		# This rebase_path's weight is the average volume of all involved pairs.
		weight =
			Enum.reduce(Enum.with_index(quote_rebase_path), 0, fn ({{rp_qa, rp_ba} = _rebase_pair, i}, sum) ->
				cond do
					# Exclude volumes of start pair.
					i === max_i ->
						sum
					# Include volumes of all other pairs.
					true ->
						rebased_phase_volume =
							combined_volume_across_exchanges(pairs[pair_id(rp_ba, rp_qa)], pairs)
							|> rebase_rate(rebase_address, rp_ba, pairs)
						sum + rebased_phase_volume
				end

			end) / Enum.count(quote_rebase_path)

		%{sums |
			volume_weighted_sum: sums.volume_weighted_sum + (weight * rebased_rate),
			combined_volume: sums.combined_volume + weight
		}
	end

	@doc """
	Expands the given path_to_expand, if necessary, by finding base address neighbors.
	"""
	defp try_expand_path_from_base([{_last_qa, last_ba} | _] = path_to_expand, rebase_address, base_neighbors, max_depth) do
		cond do
			last_ba == rebase_address ->
				[path_to_expand]
			Enum.count(path_to_expand) >= max_depth ->
				[]
			true ->
				expand_path_from_base(path_to_expand, rebase_address, base_neighbors, max_depth)
		end
	end

	@doc """
	Expands the given path_to_expand, if necessary, by finding quote address neighbors.
	"""
	defp try_expand_path_from_quote([{_last_qa, last_ba} | _] = path_to_expand, rebase_address, quote_neighbors, max_depth) do
		cond do
			last_ba == rebase_address ->
				[path_to_expand]
			Enum.count(path_to_expand) >= max_depth ->
				[]
			true ->
				expand_path_from_quote(path_to_expand, rebase_address, quote_neighbors, max_depth)
		end
	end

	@doc """
	Returns a list of all paths that expand the given path_to_expand that lead to a pair with the given rebase_address,
	by expanding to base_address neighbors.
	"""
	defp expand_path_from_base([{_last_qa, last_ba} | _] = path_to_expand, rebase_address, base_neighbors, max_depth) do
		case Rebasing.Cache.get({:expand_path_from_base, {path_to_expand, rebase_address, max_depth}}) do
			{:found, cached_result} ->
				cached_result
			{:not_found, _} ->
				result =
					case Map.has_key?(base_neighbors, last_ba) do
						true ->
							Enum.reduce(
								base_neighbors[last_ba],
								[],
								fn (new_ba, paths_acc) ->
									try_expand_path_from_base([{last_ba, new_ba} | path_to_expand], rebase_address, base_neighbors, max_depth) ++ paths_acc
								end)
						false ->
							[]
					end

				Rebasing.Cache.add({:expand_path_from_base, {path_to_expand, rebase_address, max_depth}, result})
				result
		end
	end

	@doc """
	Returns a list of all paths that expand the given path_to_expand that lead to a pair with the given rebase_address,
	by expanding to quote_address neighbors.
	"""
	defp expand_path_from_quote([{last_qa, _last_ba} | _] = path_to_expand, rebase_address, quote_neighbors, max_depth) do
		case Rebasing.Cache.get({:expand_path_from_quote, {path_to_expand, rebase_address, max_depth}}) do
			{:found, cached_result} ->
				cached_result
			{:not_found, _} ->
				result =
					case Map.has_key?(quote_neighbors, last_qa) do
						true ->
							Enum.reduce(
								quote_neighbors[last_qa],
								[],
								fn (new_qa, paths_acc) ->
									try_expand_path_from_quote([{new_qa, last_qa} | path_to_expand], rebase_address, quote_neighbors, max_depth) ++ paths_acc
								end)
						false ->
							[]
					end

				Rebasing.Cache.add({:expand_path_from_quote, {path_to_expand, rebase_address, max_depth}, result})
				result
		end
	end

	@doc """
		Calculates a volume-weighted average of the current bids and asks of a given pair across all exchanges.

		## Examples
			iex> dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
			iex> eth_address = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
			iex> eth_dai = %Dexaggregatex.Market.Structs.Pair{
			...>    base_symbol: "DAI",
			...>		quote_symbol: "ETH",
			...>		quote_address: eth_address,
			...>		base_address: dai_address,
			...>		market_data: %{
			...>			:oasis => %Dexaggregatex.Market.Structs.ExchangeMarketData{
			...>			  last_price: 0,
			...>			  current_bid: 200,
			...>			  current_ask: 400,
			...>			  base_volume: 1,
			...>		  },
			...>			:kyber => %Dexaggregatex.Market.Structs.ExchangeMarketData{
			...>				last_price: 0,
			...>				current_bid: 150,
			...>				current_ask: 300,
			...>				base_volume: 4,
			...>			}
			...>	  }
			...>  }
			iex> sample_market = %{Dexaggregatex.Market.Util.pair_id(dai_address, eth_address) => eth_dai}
			iex> Dexaggregatex.Market.Rebasing.volume_weighted_spread_average(eth_dai, sample_market)
			240.0
	"""
	def volume_weighted_spread_average(p, market) do
		case Rebasing.Cache.get({:volume_weighted_spread_average, p}) do
			{:found, cached_result} ->
				cached_result
			{:not_found, _} ->
				result =
					case Map.has_key?(market, pair_id(p)) do
						true ->
							%Pair{market_data: pmd} = market[pair_id(p)]
							combined_volume = combined_volume_across_exchanges(p, market)
							weighted_sums = %{
								current_bids: Enum.reduce(pmd, 0,
									fn ({_pair_id, %ExchangeMarketData{base_volume: bv, current_bid: cb}}, sum) -> sum + (bv * cb) end
								),
								current_asks: Enum.reduce(pmd, 0,
									fn ({_pair_id, %ExchangeMarketData{base_volume: bv, current_ask: ca}}, sum) -> sum + (bv * ca) end
								)
							}
							average(weighted_sums, combined_volume)
						false ->
							0
					end

				Rebasing.Cache.add({:volume_weighted_spread_average, p, result})
				result
		end

	end

	defp average(weighted_sums, total_sum) do
		amount_of_sums = Enum.count(weighted_sums)
		case total_sum > 0 && amount_of_sums > 0 do
			false ->
				0
			true ->
				Enum.reduce(weighted_sums, 0, fn ({_key, ws}, acc) ->
					acc + (ws / total_sum)
				end) / amount_of_sums
		end
	end
end
