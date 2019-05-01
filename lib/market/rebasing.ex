defmodule Market.Rebasing do
	@moduledoc """
		Functions for rebasing pairs of a market to a token.
	"""

	import Market.Util
	alias Market.ExchangeMarketData, as: ExchangeMarketData
	alias Market.Pair, as: Pair
	alias Market.Rebase, as: Rebase

	# Makes sure private functions are testable.
	@compile if Mix.env == :test, do: :export_all

	@doc """
		Rebases all pairs in a given market to a token with a given rebase_address as the token's address.
	"""
	def rebase_market(rebase_address, market, max_depth) do
		Enum.reduce(market, %{}, fn ({pair_id, p}, acc) ->
			rebased_pair = %{p | market_data: rebase_market_data(p, rebase_address, market, max_depth)}
			Map.put(acc, pair_id, rebased_pair)
		end)
	end

	@doc """
		Rebases all market data for a given pair to a token with a given rebase_address as the token's address.
	"""
	def rebase_market_data(%Pair{market_data: pmd, base_address: ba} = p, rebase_address, market, max_depth) do
		Enum.reduce(pmd, %{}, fn ({exchange_id, emd}, acc) ->
			rebased_emd = %{emd |
				last_price: deeply_rebase_rate(emd.last_price, p, rebase_address, market, max_depth),
				current_bid: deeply_rebase_rate(emd.current_bid, p, rebase_address, market, max_depth),
				current_ask: deeply_rebase_rate(emd.current_ask, p, rebase_address, market, max_depth),
				base_volume: deeply_rebase_rate(emd.base_volume, p, rebase_address, market, max_depth),
				quote_volume: deeply_rebase_rate(emd.quote_volume, p, rebase_address, market, max_depth),
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
			...>  Market.Util.pair_id(dai_address, eth_address) => %Market.Pair{
			...>    base_symbol: "DAI",
			...>		quote_symbol: "ETH",
			...>		quote_address: eth_address,
			...>		base_address: dai_address,
			...>		market_data: %{:oasis =>
			...>      %Market.ExchangeMarketData{
			...>			  last_price: 200,
			...>			  current_bid: 195,
			...>			  current_ask: 205,
			...>			  base_volume: 100_000,
			...>			  quote_volume: 5_000
			...>		  }
			...>	  }
			...>  }
			...> }
			iex> Rebasing.rebase_rate(100, dai_address, eth_address, sample_market)
			20_000.0
	"""
	def rebase_rate(rate, rebase_address, base_address, market) do
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
	end

	@doc """
		Calculates the combined volume across all exchanges of a given token in the market,
		denominated in the base token of the market pair.

		## Examples
			iex> dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
			iex> eth_address = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
			iex> dai_eth = %Market.Pair{
			...>    base_symbol: "DAI",
			...>		quote_symbol: "ETH",
			...>		quote_address: eth_address,
			...>		base_address: dai_address,
			...>		market_data: %{
			...>			:oasis => %Market.ExchangeMarketData{
			...>			  last_price: 0,
			...>			  current_bid: 0,
			...>			  current_ask: 0,
			...>			  base_volume: 100,
			...>			  quote_volume: 0
			...>		  },
			...>			:kyber => %Market.ExchangeMarketData{
			...>				last_price: 0,
			...>				current_bid: 0,
			...>				current_ask: 0,
			...>				base_volume: 150,
			...>				quote_volume: 0
			...>			}
			...>	  }
			...>  }
			iex> sample_market = %{Market.Util.pair_id(dai_eth) => dai_eth}
			iex> Rebasing.combined_volume_across_exchanges(dai_eth, sample_market)
			250

	"""
	def combined_volume_across_exchanges(p, market) do
		%Pair{market_data: pmd} = market[pair_id(p)]
		Enum.reduce(pmd, 0, fn ({_exchange_id, %ExchangeMarketData{base_volume: bv}}, sum) -> sum + bv end)
	end

	@doc """
		Deeply rebases a given rate of a given token in the market as the volume-weighted rate of all possible paths
		from the given base_address to the given rebase_address with a maximum path length of 2 rebases.
	"""
	def deeply_rebase_rate(rate, original_pair, rebase_address, market, max_depth) do
		%{combined_volume: cv, volume_weighted_sum: vws} =
			sums_for_deep_rebasing(rate, original_pair, rebase_address, market, max_depth)
		case cv do
			0 ->
				0
			_ ->
				vws / cv
		end
	end

	@doc """
		Calculates the values that determine a volume-weighted rate.
	"""
	defp sums_for_deep_rebasing(rate, original_pair, rebase_address, market, max_depth) do
		Enum.reduce(
			rebase_paths(rebase_address, original_pair, market, max_depth),
			%{combined_volume: 0, volume_weighted_sum: 0},
			fn (rebase_path, sums) ->
				update_sums(sums, rebase_path, rate, market, rebase_address)
			end
		)
	end

	@doc """
		Updates the given volume-weighted-rate-determining sums based on the given rebase_path.
	"""
	defp update_sums(sums, rebase_path, original_rate, market, rebase_address) do
		max_i = Enum.count(rebase_path) - 1

		# Rebase the original_rate for every pair of the rebase_path.
		rebased_rate =
			Enum.with_index(rebase_path)
			# Iterate through the rebase_path starting from the original_pair, going to the pair based in rebase_address,
			#	rebasing the original_rate to the base_address of all pairs that aren't the original one.
			|> List.foldr(original_rate,
					 fn ({%Pair{base_address: rp_ba, quote_address: rp_qa} = p, i}, acc) ->
						 case i === max_i do
							 true ->
								 acc
							 false ->
								 rebase_rate(acc, rp_ba, rp_qa, market)
						 end
					 end
				 )

		# Calculate each involved pair's combined volume and rebase it in the base address of the ultimate rebase pair.
		# This rebase_path's weight is the average volume of all involved pairs.
		weight =
			Enum.reduce(rebase_path, 0, fn (%Pair{base_address: rp_ba} = rebase_pair, sum) ->
				rebased_phase_volume =
					combined_volume_across_exchanges(rebase_pair, market)
					|> rebase_rate(rebase_address, rp_ba, market)
				sum + rebased_phase_volume
			end) / Enum.count(rebase_path)

		%{sums |
			volume_weighted_sum: sums.volume_weighted_sum + (weight * rebased_rate),
			combined_volume: sums.combined_volume + weight
		}
	end

	@doc """
		Finds all possible rebases from the given base_address to the given rebase_address with the specified depth.
	"""
	def rebase_paths(rebase_address, original_pair, market, max_depth) do
		try_expand_path([original_pair], rebase_address, market, max_depth)
	end

	@doc """
		Expands the given path_to_expand if necessary.
	"""
	defp try_expand_path([last_pair | _] = path_to_expand, rebase_address, market, max_depth) do
		cond do
			last_pair.base_address == rebase_address ->
				[path_to_expand]
			Enum.count(path_to_expand) >= max_depth ->
				nil
			true ->
				expand_path(path_to_expand, rebase_address, market, max_depth)
		end
	end

	@doc """
		Returns a list of all paths that expand the given path_to_expand.
	"""
	defp expand_path([last_pair | _] = path_to_expand, rebase_address, market, max_depth) do
		Enum.reduce(
			market,
			[],
			fn ({_id, %Pair{quote_address: next_pair_qa} = next_pair}, paths_acc) ->
				case next_pair_qa == last_pair.base_address do
					true ->
						expanded_path = [next_pair | path_to_expand]
						case try_expand_path(expanded_path, rebase_address, market, max_depth) do
							nil ->
								paths_acc
							all_paths_expanding_this ->
								all_paths_expanding_this ++ paths_acc
						end
					false ->
						paths_acc
				end
			end)
	end

	@doc """
		Calculates a volume-weighted average of the current bids and asks of a given pair across all exchanges.

		## Examples
			iex> dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
			iex> eth_address = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
			iex> eth_dai = %Market.Pair{
			...>    base_symbol: "DAI",
			...>		quote_symbol: "ETH",
			...>		quote_address: eth_address,
			...>		base_address: dai_address,
			...>		market_data: %{
			...>			:oasis => %Market.ExchangeMarketData{
			...>			  last_price: 0,
			...>			  current_bid: 200,
			...>			  current_ask: 400,
			...>			  base_volume: 1,
			...>			  quote_volume: 0
			...>		  },
			...>			:kyber => %Market.ExchangeMarketData{
			...>				last_price: 0,
			...>				current_bid: 150,
			...>				current_ask: 300,
			...>				base_volume: 4,
			...>				quote_volume: 0
			...>			}
			...>	  }
			...>  }
			iex> sample_market = %{Market.Util.pair_id(dai_address, eth_address) => eth_dai}
			iex> Rebasing.volume_weighted_spread_average(eth_dai, sample_market)
			240.0
	"""
	def volume_weighted_spread_average(p, market) do
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
