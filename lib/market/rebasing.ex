defmodule Market.Rebasing do
	@moduledoc """
		Functions for rebasing pairs of a market to a token.
	"""

	import Market.Util
	alias Market.Pair, as: Pair
	alias Market.ExchangeMarketData, as: ExchangeMarketData

	# Makes sure private functions are testable.
	@compile if Mix.env == :test, do: :export_all

	@doc """
		Rebases all pairs in a given market to a token with a given rebase_address.
	"""
	def rebase_market(rebase_address, market) do
		Enum.reduce(market, %{}, fn ({pKey, p}, acc) ->
			rebased_pair = %{p | market_data: rebase_market_data(p, rebase_address, market)}
			Map.put(acc, pKey, rebased_pair)
		end)
	end

	@doc """
		Rebases all market data for a given pair to a token with a given rebase_address.
	"""
	def rebase_market_data(p, rebase_address, market) do
		Enum.reduce(p.market_data, %{}, fn ({exchange_id, emd}, acc) ->
			rebased_market_data = %ExchangeMarketData{
				last_price: deeply_rebase_rate(emd.last_price, rebase_address, p.base_address, p.quote_address, market),
				current_bid: deeply_rebase_rate(emd.current_bid, rebase_address, p.base_address, p.quote_address, market),
				current_ask: deeply_rebase_rate(emd.current_ask, rebase_address, p.base_address, p.quote_address, market),
				base_volume: deeply_rebase_rate(emd.base_volume, rebase_address, p.base_address, p.quote_address, market),
				quote_volume: deeply_rebase_rate(emd.quote_volume, rebase_address, p.base_address, p.quote_address, market),
			}
			Map.put(acc, exchange_id, rebased_market_data)
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
			...>		quote_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
			...>		base_address: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
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
		cond do
			rebase_address == base_address ->
				rate
			rebase_address != base_address ->
				rebase_pair_id = pair_id(rebase_address, base_address)
				case Map.has_key?(market, rebase_pair_id) do
					true ->
						rate * volume_weighted_spread_average(rebase_address, base_address, market)
					false ->
						0
				end
		end
	end

	@doc """
		Calculates the combined volume across all exchanges of a given token in the market.
	"""
	def combined_volume_across_exchanges(base_address, quote_address, market) do
		pmd = market[pair_id(base_address, quote_address)].market_data
		Enum.reduce(pmd, 0, fn ({_exchange_id, emd}, sum) -> sum + emd.base_volume end)
	end

	@doc """
		Deeply rebases a given rate of a given token in the market as the volume-weighted rate of all possible paths
		from the given base_address to the given rebase_address with a maximum path length of 2 rebases.
	"""
	def deeply_rebase_rate(rate, rebase_address, base_address, quote_address, market) do
		case rebase_address == base_address do
			true ->
				rate
			false ->
				original_pair = market[pair_id(base_address, quote_address)]
				immediate_rebase_pair = market[pair_id(rebase_address, base_address)]

				start_sums = %{:volume_weighted_sum => 0, :combined_volume => 0}
				sums =
					update_sums_level2(start_sums, rate, original_pair, rebase_address, base_address, market)
					|> update_sums_level1(rate, original_pair, immediate_rebase_pair, market)

				case sums[:combined_volume] do
					0 ->
						0
					not_zero ->
						sums[:volume_weighted_sum] / not_zero
				end
		end
	end

	defp update_sums_level1(sums, rate, original_pair, immediate_rebase_pair, market) do
		case immediate_rebase_pair do
			nil ->
				sums
			_ ->
				phase1_volume = combined_volume_across_exchanges(original_pair.base_address, original_pair.quote_address, market)
				rebased_phase1_volume = rebase_rate(phase1_volume, immediate_rebase_pair.base_address, original_pair.base_address, market)
				phase2_volume = combined_volume_across_exchanges(immediate_rebase_pair.base_address, immediate_rebase_pair.quote_address, market)
				rebased_phase2_volume = rebase_rate(phase2_volume, immediate_rebase_pair.base_address, immediate_rebase_pair.base_address, market)

				rebased_path_volume = rebased_phase1_volume + rebased_phase2_volume

				rebased_rate = rebase_rate(rate, immediate_rebase_pair.base_address, original_pair.base_address, market)

				prev_volume_weighted_sum = sums[:volume_weighted_sum]
				prev_combined_volume = sums[:combined_volume]

				%{sums |
					volume_weighted_sum: prev_volume_weighted_sum + (rebased_path_volume * rebased_rate),
					combined_volume: prev_combined_volume + rebased_path_volume
				}
		end
	end

	defp update_sums_level2(sums, rate, original_pair, rebase_address, base_address, market) do
		l2_rebases = level2_rebases(rebase_address, base_address, market)
		Enum.reduce(l2_rebases, sums, fn (l2_rebase, acc) ->
			phase1_volume = combined_volume_across_exchanges(original_pair.base_address, original_pair.quote_address, market)
			rebased_phase1_volume = rebase_rate(phase1_volume, l2_rebase[:p1].base_address, base_address, market)
			phase2_volume = combined_volume_across_exchanges(l2_rebase[:p1].base_address, l2_rebase[:p1].quote_address, market)
			rebased_phase2_volume = rebase_rate(phase2_volume, l2_rebase[:p2].base_address, l2_rebase[:p1].base_address, market)
			phase3_volume = combined_volume_across_exchanges(l2_rebase[:p2].base_address, l2_rebase[:p2].quote_address, market)
			rebased_phase3_volume = rebase_rate(phase3_volume, rebase_address, l2_rebase[:p2].base_address, market)

			rebased_path_volume = rebased_phase1_volume + rebased_phase2_volume + rebased_phase3_volume

			rebased_phase1_rate = rebase_rate(rate, l2_rebase[:p1].base_address, base_address, market)
			rebased_phase2_rate = rebase_rate(rebased_phase1_rate, l2_rebase[:p2].base_address, l2_rebase[:p1].base_address, market)

			prev_volume_weighted_sum = acc[:volume_weighted_sum]
			prev_combined_volume = acc[:combined_volume]

			%{acc |
				volume_weighted_sum: prev_volume_weighted_sum + (rebased_path_volume * rebased_phase2_rate),
				combined_volume: prev_combined_volume + rebased_path_volume
			}
		end)
	end

	@doc """
		Finds all possible rebases from the given base_address to the given rebase_address with a maximum depth of 2 rebases.
	"""
	def level2_rebases(rebase_address, base_address, market) do
		Enum.reduce(market, [], fn ({_id, p2}, acc1) ->
			case p2.base_address == rebase_address do
				true ->
					Enum.reduce(market, acc1, fn ({_id, p1}, acc2) ->
						case (p1.base_address == p2.quote_address && base_address == p1.quote_address) do
							true ->
								acc2 ++ %{:p1 => p1, :p2 => p2}
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
		Calculates a volume-weighted average of the current bids and asks of a given pair across all exchanges.
	"""
	def volume_weighted_spread_average(base_address, quote_address, market) do
		pmd = market[pair_id(base_address, quote_address)].market_data
		combined_volume = combined_volume_across_exchanges(base_address, quote_address, market)
		weighted_sum_of_current_bids = Enum.reduce(pmd, 0, fn ({_, emd}, sum) ->
			sum + (emd.base_volume * emd.current_bid)
		end)
		weighted_sum_of_current_asks = Enum.reduce(pmd, 0, fn ({_, emd}, sum) ->
			sum + (emd.base_volume * emd.current_ask)
		end)
		volume_weighted_bid_average = weighted_sum_of_current_bids / combined_volume
		volume_weighted_ask_average = weighted_sum_of_current_asks / combined_volume
		(volume_weighted_bid_average + volume_weighted_ask_average) / 2
	end
end
