defmodule Dexaggregatex.Market.Rebasing do
	@moduledoc """
	Logic for rebasing pairs of a market to a token, denominating all rates in this token.
	"""

	alias Dexaggregatex.Market.Structs.{Market, ExchangeMarketData, Pair, RebasedMarket}
	alias Dexaggregatex.Market.Rebasing
	alias Dexaggregatex.Market.Rebasing.{Neighbors, Paths}
	import Dexaggregatex.Market.Util
	import Dexaggregatex.Util

	# Makes sure private functions are testable.
	@compile if Mix.env == :test, do: :export_all

	@doc """
	Rebases all pairs in a given market to a token with a given rebase_address.
	"""
	def rebase_market(rebase_address, %Market{pairs: pairs} = m, max_depth) do
		rebased_pairs =
			case Rebasing.Cache.get({:rebase_market, {rebase_address, max_depth}}) do
				{:found, cached_market} ->
					cached_market
				{:not_found, _} ->
					created_tasks = Enum.map(pairs, fn ({pair_id, p}) ->
						{pair_id, Task.async(fn -> rebase_pair(p, rebase_address, m, max_depth) end)}
					end)

					rebased_market = Enum.reduce(created_tasks, %{}, fn ({k, p}, acc) ->
						result = Task.await(p, 60_000)
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

  def rebase_pair(p, rebase_address, %Market{} = m, max_depth) do
    %{p | market_data: rebase_market_data(p, rebase_address, m, max_depth)}
  end

	@doc """
	Rebases all market data for a given pair to a token with a given rebase_address as the token's address.
	"""
	defp rebase_market_data(%Pair{market_data: pmd} = p, rebase_address, %Market{pairs: pairs} = m, max_depth) do
		Enum.reduce(pmd, %{}, fn ({exchange_id, emd}, acc) ->
			p_id = pair_id(p)
			brp = try_expand_path([p_id], rebase_address, max_depth, pairs, :base)
			qrp = try_expand_path([p_id], rebase_address, max_depth, pairs, :quote)
			rebased_emd = %{emd |
				last_price: deeply_rebase_rate(emd.last_price, p, rebase_address, m, max_depth, brp, qrp),
				current_bid: deeply_rebase_rate(emd.current_bid, p, rebase_address, m, max_depth, brp, qrp),
				current_ask: deeply_rebase_rate(emd.current_ask, p, rebase_address, m, max_depth, brp, qrp),
				base_volume: deeply_rebase_rate(emd.base_volume, p, rebase_address, m, max_depth, brp, qrp),
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
			...>				timestamp: :os.system_time(:millisecond)
			...>		  }
			...>	  }
			...>  }
			...> }
			iex> trunc(Dexaggregatex.Market.Rebasing.rebase_rate(100, dai_address, eth_address, sample_market))
			20_000
	"""
	defp rebase_rate(rate, rebase_address, base_address, pairs) do
		case rebase_address == base_address do
			true -> rate
			false ->
				rebase_pair_id = pair_id(rebase_address, base_address)
				case Map.has_key?(pairs, rebase_pair_id) do
					true -> rate * volume_weighted_spread_average(pairs[rebase_pair_id])
					false -> 0
				end
		end
	end

	@doc """
	Deeply rebases a given rate of a given token in the market as the volume-weighted rate of all possible paths
	from the given base_address to the given rebase_address with a maximum path length of 2 rebases.
	"""
	defp deeply_rebase_rate(rate, original_pair, rebase_address, %Market{pairs: pairs} = _m, max_depth, brp, qrp) do
		%{combined_volume: cv, volume_weighted_sum: vws} =
			sums_for_deep_rebasing(rate, original_pair, rebase_address, pairs, max_depth, brp, qrp)

		safe_div(vws, cv)
	end

	@doc """
	Calculates the values that determine a volume-weighted rate.
	"""
	defp sums_for_deep_rebasing(rate, original_pair, rebase_address, pairs, max_depth, brp, qrp) do
		r =
			Enum.reduce(brp, %{combined_volume: 0, volume_weighted_sum: 0}, fn (base_rebase_path, sums) ->
				base_update_sums(sums, base_rebase_path, rate, pairs, rebase_address)
			end)
		Enum.reduce(qrp, r, fn (quote_rebase_path, sums) ->
			quote_update_sums(sums, quote_rebase_path, rate, pairs, rebase_address)
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
				fn ({rp_id, i}, acc) ->
					%Pair{base_address: rp_ba, quote_address: rp_qa} = pairs[rp_id]
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
			Enum.reduce(Enum.with_index(base_rebase_path), 0, fn ({rp_id, i}, sum) ->
				%Pair{base_address: rp_ba} = pairs[rp_id]
				cond do
          # Exclude volumes of start pair.
          i === max_i ->
            sum
          # Include volumes of all other pairs.
          true ->
            rebased_phase_volume =
              combined_volume_across_exchanges(pairs[rp_id])
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
					 fn ({rp_id, i}, acc) ->
						 %Pair{base_address: rp_ba, quote_address: rp_qa} = pairs[rp_id]
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
			Enum.reduce(Enum.with_index(quote_rebase_path), 0, fn ({rp_id, i}, sum) ->
				%Pair{base_address: rp_ba} = pairs[rp_id]
				cond do
					# Exclude volumes of start pair.
					i === max_i ->
						sum
					# Include volumes of all other pairs.
					true ->
						rebased_phase_volume =
							combined_volume_across_exchanges(pairs[rp_id])
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
	Expands the given path_to_expand, if necessary, by finding neighbors in the specified `from` direction.
	"""
	defp try_expand_path([last_p_id | _] = path_to_expand, rebase_address, max_depth, pairs, from) do
		%Pair{base_address: last_ba} = pairs[last_p_id]
		cond do
			last_ba == rebase_address -> [path_to_expand]
			Enum.count(path_to_expand) >= max_depth -> []
			true -> expand_path(path_to_expand, rebase_address, max_depth, pairs, from)
		end
	end

	@doc """
	Returns a list of all paths that expand the given path_to_expand that lead to a pair with the given rebase_address,
	by expanding in the specified `from` direction.
	"""
	defp expand_path([last_p_id | _] = path_to_expand, rebase_address, max_depth, pairs, from) do
		case from do
			:base -> Neighbors.get_base_neighbors(last_p_id)
			:quote -> Neighbors.get_quote_neighbors(last_p_id)
		end

		|> Enum.reduce([], fn (n_p_id, paths_acc) ->
			try_expand_path([n_p_id | path_to_expand], rebase_address, max_depth, pairs, from) ++ paths_acc
		end)
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
			...>				timestamp: :os.system_time(:millisecond)
			...>		  },
			...>			:kyber => %Dexaggregatex.Market.Structs.ExchangeMarketData{
			...>				last_price: 0,
			...>				current_bid: 150,
			...>				current_ask: 300,
			...>				base_volume: 4,
			...>				timestamp: :os.system_time(:millisecond)
			...>			}
			...>	  }
			...>  }
			iex> Dexaggregatex.Market.Rebasing.volume_weighted_spread_average(eth_dai)
			240.0
	"""
	defp volume_weighted_spread_average(%Pair{market_data: pmd} = p) do
		combined_volume = combined_volume_across_exchanges(p)
		weighted_sums = %{
			current_bids: Enum.reduce(pmd, 0,
				fn ({_eid, %ExchangeMarketData{base_volume: bv, current_bid: cb} = emd}, sum) -> sum + (bv * cb) end),
			current_asks: Enum.reduce(pmd, 0,
				fn ({_eid, %ExchangeMarketData{base_volume: bv, current_ask: ca} = emd}, sum) -> sum + (bv * ca) end)
		}
		weighted_average(weighted_sums, combined_volume)
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
			...>				timestamp: :os.system_time(:millisecond)
			...>		  },
			...>			:kyber => %Dexaggregatex.Market.Structs.ExchangeMarketData{
			...>				last_price: 0,
			...>				current_bid: 0,
			...>				current_ask: 0,
			...>				base_volume: 150,
			...>				timestamp: :os.system_time(:millisecond)
			...>			}
			...>	  }
			...>  }
			iex> Dexaggregatex.Market.Rebasing.combined_volume_across_exchanges(dai_eth)
			250

	"""
	defp combined_volume_across_exchanges(%Pair{market_data: pmd}) do
		Enum.reduce(pmd, 0, fn ({_exchange_id, %ExchangeMarketData{base_volume: bv}}, sum) -> sum + bv end)
	end
end
