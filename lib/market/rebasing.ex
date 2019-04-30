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
	def rebase_market(rebase_address, market) do
		Enum.reduce(market, %{}, fn ({pair_id, p}, acc) ->
			rebased_pair = %{p | market_data: rebase_market_data(p, rebase_address, market)}
			Map.put(acc, pair_id, rebased_pair)
		end)
	end

	@doc """
		Rebases all market data for a given pair to a token with a given rebase_address as the token's address.
	"""
	def rebase_market_data(p, rebase_address, market) do
		Enum.reduce(p.market_data, %{}, fn ({exchange_id, emd}, acc) ->
			rebased_emd = %ExchangeMarketData{
				last_price: deeply_rebase_rate(emd.last_price, rebase_address, p.base_address, p.quote_address, market),
				current_bid: deeply_rebase_rate(emd.current_bid, rebase_address, p.base_address, p.quote_address, market),
				current_ask: deeply_rebase_rate(emd.current_ask, rebase_address, p.base_address, p.quote_address, market),
				base_volume: deeply_rebase_rate(emd.base_volume, rebase_address, p.base_address, p.quote_address, market),
				quote_volume: deeply_rebase_rate(emd.quote_volume, rebase_address, p.base_address, p.quote_address, market),
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
		pmd = market[pair_id(p)].market_data
		Enum.reduce(pmd, 0, fn ({_exchange_id, emd}, sum) -> sum + emd.base_volume end)
	end

	@doc """
		Deeply rebases a given rate of a given token in the market as the volume-weighted rate of all possible paths
		from the given base_address to the given rebase_address with a maximum path length of 2 rebases.
	"""
	def deeply_rebase_rate(rate, %Pair{base_address: ba, quote_address: qa} = original_pair, rebase_address, market) do
		case rebase_address == ba do
			true ->
				rate
			false ->
				immediate_rebase_pair = market[pair_id(rebase_address, ba)]

				start_sums = %{:volume_weighted_sum => 0, :combined_volume => 0}
				sums =
					update_sums_level2(start_sums, rate, original_pair, rebase_address, market)
					|> update_sums_level1(rate, original_pair, immediate_rebase_pair, market)

				case sums.combined_volume do
					0 ->
						0
					_ ->
						sums.volume_weighted_sum / sums.combined_volume
				end
		end
	end

	defp update_sums_level1(sums, rate, %Pair{base_address: op_ba, quote_address: op_qa} = op,
				 %Pair{base_address: irp_ba, quote_address: irp_qa} = irp, market) do
		case immediate_rebase_pair do
			nil ->
				sums
			_ ->
				rebased_rate = rebase_rate(rate, irp_ba, op_ba, market)

				# Calculate each involved pair's combined volume and rebase it in the base address of the immediate rebase token.
				phase1_volume = combined_volume_across_exchanges(op, market)
				rebased_phase1_volume = rebase_rate(phase1_volume, irp_ba, op_ba, market)
				phase2_volume = combined_volume_across_exchanges(irp, market)
				rebased_phase2_volume = rebase_rate(phase2_volume, irp_ba, irp_ba, market)

				rebased_path_volume = rebased_phase1_volume + rebased_phase2_volume

				prev_volume_weighted_sum = sums.volume_weighted_sum
				prev_combined_volume = sums.combined_volume

				%{sums |
					volume_weighted_sum: prev_volume_weighted_sum + (rebased_path_volume * rebased_rate),
					combined_volume: prev_combined_volume + rebased_path_volume
				}
		end
	end

	defp update_sums_level2(sums, rate, %Pair{base_address: op_ba, quote_address: op_qa} = op, rebase_address, market) do
		Enum.reduce(level2_rebases(rebase_address, op_ba, market), sums, fn
			(%{
				 p1: %Pair{base_address: rp1_ba, quote_address: rp1_qa} = rp1,
				 p2: %Pair{base_address: rp2_ba, quote_address: rp2_qa} = rp2
			 } = l2_rebase, sums) ->
				rebased_rate =
					rebase_rate(rate, rp1_ba, op_ba, market)
					|> rebase_rate(rp2_ba, rp1_ba, market)

				phase1_volume = combined_volume_across_exchanges(op, market)
				rebased_phase1_volume = rebase_rate(phase1_volume, rp2_ba, op_ba, market)
				phase2_volume = combined_volume_across_exchanges(rp1, market)
				rebased_phase2_volume = rebase_rate(phase2_volume, rp2_ba, rp1_ba, market)
				phase3_volume = combined_volume_across_exchanges(rp2, market)
				rebased_phase3_volume = rebase_rate(phase3_volume, rp2_ba, rp2_ba, market)

				rebased_path_volume = rebased_phase1_volume + rebased_phase2_volume + rebased_phase3_volume

				%{sums |
					volume_weighted_sum: sums.volume_weighted_sum + (rebased_path_volume * rebased_rate),
					combined_volume: sums.combined_volume + rebased_path_volume
				}
		end)
	end

	@doc """
		Finds all possible rebases from the given base_address to the given rebase_address with a maximum depth of 2 rebases.
	"""
	def level2_rebases(rebase_address, base_address, market) do
		Enum.reduce(market, [], fn ({_id, %Pair{base_address: p2_ba, quote_address: p2_qa} = p2}, acc1) ->
			case p2_ba == rebase_address do
				true ->
					Enum.reduce(market, acc1, fn ({_id, %Pair{base_address: p1_ba, quote_address: p1_qa} = p1}, acc2) ->
						case (base_address == p1_qa && p1_ba == p2_qa) do
							true ->
								acc2 ++ [%{p1: p1, p2: p2}]
							false ->
								acc2
						end
					end)
				false ->
					acc1
			end
		end)
	end

	@doc """
		Finds all possible rebases from the given base_address to the given rebase_address with a maximum depth of 3 rebases.
	"""
	def level3_rebases(rebase_address, base_address, market) do
		Enum.reduce(market, [], fn ({_id, %Pair{base_address: p3_ba, quote_address: p3_qa} = p3}, acc1) ->
			case p3_ba == rebase_address do
				true ->
					Enum.reduce(market, acc1, fn ({_id, %Pair{base_address: p2_ba, quote_address: p2_qa} = p2}, acc2) ->
						case p3_qa == p2_ba do
							true ->
								Enum.reduce(market, acc2, fn ({_id, %Pair{base_address: p1_ba, quote_address: p1_qa} = p1}, acc3) ->
									case (p2_qa == p1_ba && p1_qa == base_address) do
										true ->
											# Prepend merely for performance reasons
											[%Rebase{p1: p1, p2: p2, p3: p3} | acc3]
										false ->
											acc3
									end
								end)
							false ->
								acc2
						end
					end)
				false ->
					acc1
			end
		end)
	end

	@doc """
		Finds all possible rebases from the given base_address to the given rebase_address with the specified depth.
	"""
	def specific_depth_rebases(%Pair{base_address: rebase_pair_ba} = rebase_pair, base_pair, market, depth) do
		try_expand_path([base_pair], rebase_pair, market, 0, 2)
	end

	defp expand_path(path_to_update, base_address, market, depth) do
		own_acc = path_to_update
		own_acc =
			for i <- depth - 2 do
				Enum.reduce(
					market,
					path_to_update,
					fn (
						 {_id, %Pair{quote_address: next_pair_qa} = next_pair},
						 [%Pair{base_address: prev_pair_ba} | _] = all_paths
					) ->
						case next_pair_qa == prev_pair_ba do
							true ->
								[next_pair | path_acc]
							false ->
								nil
						end
					end)
			end
		|> add_first_pair(base_address, market)
	end

	@doc """
		Expands the given path_to_expand if necessary.
	"""
	defp try_expand_path([last_pair | _] = path_to_expand, rebase_pair, market, current_depth, maximum_depth) do
		cond do
			last_pair == rebase_pair || current_depth == maximum_depth ->
				path_to_expand
			last_pair != rebase_pair ->
				expand_path(path_to_expand, rebase_pair, market, current_depth, maximum_depth)
		end
	end

	@doc """
		Returns all paths that expand the given path_to_expand.
	"""
	defp expand_path(path_to_expand, rebase_pair, market, current_depth, maximum_depth) do
		Enum.reduce(
			market,
			path_to_expand,
			fn (
				 {_id, %Pair{quote_address: next_pair_qa} = next_pair},
				 [%Pair{base_address: prev_pair_ba} | _] = paths_acc
				 ) ->
				case next_pair_qa == prev_pair_ba do
					true ->
						one_pair_expanded_path = [next_pair | path_to_expand]
						try_expand_path(one_pair_expanded_path, market) ++ paths_acc
					false ->
						nil
				end
			end)
	end

	defp add_first_pair(path_to_update, base_address, market) do
		case path_to_update do
			nil ->
				nil
			_ ->
				Enum.reduce(
					market,
					path_to_update,
					fn (
						 {_id, %Pair{base_address: first_pair_ba, quote_address: first_pair_qa} = first_pair},
						 [%Pair{base_address: prev_pair_ba} | _] = path_acc
						 ) ->
						case (prev_pair_ba == first_pair_ba && first_pair_qa == base_address) do
							true ->
								full_path = [first_pair | path_acc]
								Enum.reduce(Enum.with_index(full_path), %Rebase{}, fn ({rebase_pair, i}, rebase) ->
									%{rebase | String.to_atom("p#{i}") => rebase_pair}
								end)
							false ->
								nil
						end
					end)
		end
	end



	@doc """
		end
		Enum.reduce(market, [], fn ({_id, %Pair{base_address: p3_ba, quote_address: p3_qa} = p3}, acc1) ->
			case rebase_address == p3_ba do
				true ->
					Enum.reduce(market, acc1, fn ({_id, %Pair{base_address: p2_ba, quote_address: p2_qa} = p2}, acc2) ->
						case p3_qa == p2_ba do
							true ->
								Enum.reduce(market, acc2, fn ({_id, %Pair{base_address: p1_ba, quote_address: p1_qa} = p1}, acc3) ->
									case (p2_qa == p1_ba && p1_qa == base_address) do
										true ->
											# Prepend merely for performance reasons
											[%Rebase{p1: p1, p2: p2, p3: p3} | acc3]
										false ->
											acc3
									end
								end)
							false ->
								acc2
						end
					end)
				false ->
					acc1
			end
		end)
	end

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
		pmd = market[pair_id(p)].market_data
		combined_volume = combined_volume_across_exchanges(p, market)
		weighted_sums = %{
			current_bids: Enum.reduce(pmd, 0,
				fn ({_pair_id, %ExchangeMarketData{base_volume: bv, current_bid: cb}}, sum) -> sum + (bv * cb) end),
			current_asks: Enum.reduce(pmd, 0,
				fn ({_pair_id, %ExchangeMarketData{base_volume: bv, current_ask: ca}}, sum) -> sum + (bv * ca) end)
		}
		average(weighted_sums, combined_volume)
	end

	defp average(weighted_sums, total_sum) do
		case total_sum >= 0 && amount_of_sums >= 0 do
			false ->
				0
			true ->
				Enum.reduce(weighted_sums, 0, fn (ws, acc) ->
					acc + (ws / total_sum)
				end) / Enum.count(weighted_sums)
		end
	end
end
