defmodule Rebasing do
	@moduledoc """
		Functions for rebasing pairs of a DexAggregate market to a token.
	"""

	@doc """
		Rebases all pairs in a given market to a token with a given rebase_address.
	"""
	def rebase_market(rebase_address, market) do
		Enum.map(market, fn {pKey, p} ->
			{pKey, %{p | market_data: rebase_market_data(p, rebase_address, market)}}
		end)
	end

	@doc """
		Rebases all market data for a given pair to a token with a given rebase_address.
	"""
	def rebase_market_data(p, rebase_address, market) do
		Enum.reduce(p[:market_data], %{}, fn (result, {exchange_id, emd}) ->
			rebased_market_data = %{
				exchange: exchange_id,
				rebased_last_price: deeply_rebase_rate(emd[:last_price], rebase_address, p[:base_address], p[:quote_address], market),
				rebased_current_bid: deeply_rebase_rate(emd[:current_bid], rebase_address, p[:base_address], p[:quote_address], market),
				rebased_current_ask: deeply_rebase_rate(emd[:current_ask], rebase_address, p[:base_address], p[:quote_address], market),
				rebased_base_volume: deeply_rebase_rate(emd[:base_volume], rebase_address, p[:base_address], p[:quote_address], market),
			}
			Map.put(result, exchange_id, rebased_market_data)
		end)
	end

	@doc """
		Rebases a given rate of a pair based in a token with a given base_address to a token with a given rebase_address.
	"""
	def rebase_rate(rate, rebase_address, base_address, market) do
		cond do
			rebase_address == base_address ->
				rate
			rebase_address != base_address ->
				rebase_pair_id = Base.encode64(:crypto.hash(:sha512, "#{rebase_address}/#{base_address}"))
				case Map.has_key?(market, rebase_pair_id) do
					true ->
						rate * volume_weighted_spread_average(rebase_address, base_address, market)
					false ->
						nil
				end
		end
	end

	@doc """
		Calculates the combined volume across all exchanges of a given token in the market.
	"""
	def combined_volume_across_exchanges(base_address, quote_address, market) do
		pair_id = Base.encode64(:crypto.hash(:sha512, "#{base_address}/#{quote_address}"))
		pair = market[pair_id]
		Enum.reduce(pair, 0, fn (sum, pair_on_exchange) -> sum + pair_on_exchange[:market_data][:base_volume] end)
	end

	@doc """
		Deeply rebases a given rate of a given token in the market as the volume-weighted rate of all possible paths
		from the given base_address to the given rebase_address with a maximum path length of 2 rebases.
	"""
	def deeply_rebase_rate(rate, rebase_address, base_address, quote_address, market) do
		cond do
			rebase_address == base_address ->
				rate
			rebase_address != base_address ->
				original_pair_id = Base.encode64(:crypto.hash(:sha512, "#{base_address}/#{quote_address}"))
				original_pair = market[original_pair_id]
				immediate_rebase_pair_id = Base.encode64(:crypto.hash(:sha512, "#{rebase_address}/#{base_address}"))
				immediate_rebase_pair = market[immediate_rebase_pair_id]

				start_sums = %{:volume_weighted_sum => 0, :combined_volume => 0}

				sums =
					update_sums_level2(start_sums, rate, original_pair, rebase_address, base_address, market)
					|> update_sums_level1(rate, original_pair, immediate_rebase_pair, rebase_address, market)

				sums[:volume_weighted_sum] / sums[:combined_volume]
		end
	end

	defp update_sums_level1(sums, rate, original_pair, immediate_rebase_pair, rebase_address, market) do
		case immediate_rebase_pair do
			true ->
				phase1_volume = combined_volume_across_exchanges(immediate_rebase_pair[:base_address], original_pair[:quote_address], market)
				rebased_phase1_volume = rebase_rate(phase1_volume, immediate_rebase_pair[:base_address], original_pair[:base_address], market)
				phase2_volume = combined_volume_across_exchanges(immediate_rebase_pair[:base_address], immediate_rebase_pair[:quote_address], market)
				rebased_phase2_volume = rebase_rate(phase2_volume, rebase_address, immediate_rebase_pair[:base_address], market)

				rebased_path_volume = rebased_phase1_volume + rebased_phase2_volume

				rebased_rate = rebase_rate(rate, immediate_rebase_pair[:base_address], original_pair[:base_address], market)

				prev_volume_weighted_sum = sums[:volume_weighted_sum]
				prev_combined_volume = sums[:combined_volume]

				%{sums |
					volume_weighted_sum: prev_volume_weighted_sum + (rebased_path_volume * rebased_rate),
					combined_volume: prev_combined_volume + rebased_path_volume
				}
			false ->
				sums
		end
	end

	defp update_sums_level2(sums, rate, original_pair, rebase_address, base_address, market) do
		l2_rebases = level2_rebases(rebase_address, base_address, market)
		Enum.reduce(l2_rebases, sums, fn (acc, l2_rebase) ->
			phase1_volume = combined_volume_across_exchanges(original_pair[:base_address], original_pair[:quote_address], market)
			rebased_phase1_volume = rebase_rate(phase1_volume, l2_rebase[:p1][:base_address], base_address, market)
			phase2_volume = combined_volume_across_exchanges(l2_rebase[:p1][:base_address], l2_rebase[:p1][:quote_address], market)
			rebased_phase2_volume = rebase_rate(phase2_volume, l2_rebase[:p2][:base_address], l2_rebase[:p1][:base_address], market)
			phase3_volume = combined_volume_across_exchanges(l2_rebase[:p2][:base_address], l2_rebase[:p2][:quote_address], market)
			rebased_phase3_volume = rebase_rate(phase3_volume, rebase_address, l2_rebase[:p2][:base_address], market)

			rebased_path_volume = rebased_phase1_volume + rebased_phase2_volume + rebased_phase3_volume

			rebased_phase1_rate = rebase_rate(rate, l2_rebase[:p1][:base_address], base_address, market)
			rebased_phase2_rate = rebase_rate(rebased_phase1_rate, l2_rebase[:p2][:base_address], l2_rebase[:p1][:base_address], market)

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
		Enum.reduce(market, [], fn (acc1, p2) ->
			case p2[:base_address] == rebase_address do
				true ->
					Enum.reduce(market, acc1, fn (acc2, p1) ->
						case (p1[:base_address] == p2[:quote_address] && base_address == p1[:quote_address]) do
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
		pair_id = Base.encode64(:crypto.hash(:sha512, "#{base_address}/#{quote_address}"))
		pair = market[pair_id]
		combined_volume = combined_volume_across_exchanges(base_address, quote_address, market)
		weighted_sum_of_current_bids = Enum.reduce(pair[:market_data], 0, fn (result, emd) ->
			result + (emd[:base_volume] * emd[:current_bid])
		end)
		weighted_sum_of_current_asks = Enum.reduce(pair[:market_data], 0, fn (result, emd) ->
			result + (emd[:base_volume] * emd[:current_ask])
		end)
		volume_weighted_bid_average = weighted_sum_of_current_bids / combined_volume
		volume_weighted_ask_average = weighted_sum_of_current_asks / combined_volume
		(volume_weighted_bid_average + volume_weighted_ask_average) / 2
	end




end
