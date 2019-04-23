defmodule Rebasing do
	@moduledoc """
		Functions for rebasing all pairs of a DexAggregate market to a currency.
	"""

	@doc """
		Rebases all pairs in a given market to a token with a given market_rebase_address.
	"""
	def rebase_market(market, market_rebase_address) do
		@doc """
			Rebases a given rate of a pair based in a token with a given base_address to a token with a given rebase_address.
		"""
		def rebase_rate(rebase_address, base_address, rate) do
			cond do
				rebase_address == base_address ->
					rate
				rebase_address != base_address ->
					rebase_pair_id = Base.encode64(:crypto.hash(:sha512, "#{rebase_address}/#{base_address}"))
					case Map.has_key?(market, rebase_pair_id) do
						true ->
							rebase_pair = market[rebase_pair_id]
							rate * volume_weighted_spread_average(rebase_address, base_address)
						false ->
							nil
					end
			end
		end

		def get_total_volume_across_exchanges(base_address, quote_address) do
			pair_id = Base.encode64(:crypto.hash(:sha512, "#{base_address}/#{quote_address}"))
			pair = market[pair_id]
			Map.reduce(pair, 0, fn (sum, pair_on_exchange) -> sum + pair_on_exchange[:market_data][:base_volume] end)
		end

		def deeply_rebase_rate(rebase_address, base_address, quote_address, rate) do
			cond do
				rebase_address == base_address ->
					rate
				rebase_address != base_address ->
					original_pair_id = Base.encode64(:crypto.hash(:sha512, "#{base_address}/#{quote_address}"))
					original_pair = market[original_pair_id]
					immediate_rebase_pair_id = Base.encode64(:crypto.hash(:sha512, "#{rebase_address}/#{base_address}"))

					start_sums = %{:volume_weighted_sum => 0, :combined_volume => 0}

					sums = Enum.reduce(level2_rebases(), start_sums, fn (acc, l2_rebase) ->
						phase1_volume = get_total_volume_across_exchanges(original_pair[:base_address], original_pair[:quote_address])
						rebased_phase1_volume = rebase_rate(l2_rebase[:p1][:base_address], base_address, phase1_volume)
						phase2_volume = get_total_volume_across_exchanges(l2_rebase[:p1][:base_address], l2_rebase[:p1][:quote_address])
						rebased_phase2_volume = rebase_rate(l2_rebase[:p2][:base_address], l2_rebase[:p1][:base_address], phase2_volume)
						phase3_volume = get_total_volume_across_exchanges(l2_rebase[:p2][:base_address], l2_rebase[:p2][:quote_address])
						rebased_phase3_volume = rebase_rate(rebase_address, l2_rebase[:p2][:base_address], phase3_volume)

						rebased_path_volume = rebased_phase1_volume + rebased_phase2_volume + rebased_phase3_volume

						rebased_phase1_rate = rebase_rate(l2_rebase[:p1][:base_address], base_address, rate)
						rebased_phase2_rate = rebase_rate(l2_rebase[:p2][:base_address], l2_rebase[:p1][:base_address], rebased_phase1_rate)

						prev_volume_weighted_sum = acc[:volume_weighted_sum]
						prev_combined_volume = acc[:combined_volume]

						acc = %{acc |
							volume_weighted_sum: prev_volume_weighted_sum + (rebased_path_volume * rebased_phase2_rate),
							combined_volume: prev_combined_volume + rebased_path_volume
						}
					end)

					sums = case Map.has_key?(market, rebase_pair_id) do
						true ->
							immediate_rebase_pair = market[immediate_rebase_pair_id]
							phase1_volume = get_total_volume_across_exchanges(immediate_rebase_pair[:base_address], original_pair[:quote_address])
							rebased_phase1_volume = rebase_rate(immediate_rebase_pair[:base_address], original_pair[:base_address], phase1_volume)
							phase2_volume = get_total_volume_across_exchanges(immediate_rebase_pair[:base_address], immediate_rebase_pair[:quote_address])
							rebased_phase2_volume = rebase_rate(rebase_address, immediate_rebase_pair[:base_address], phase2_volume)

							rebased_path_volume = rebased_phase1_volume + rebased_phase2_volume

							rebased_rate = rebase_rate(immediate_rebase_pair[:base_address], original_pair[:base_address], rate)

							prev_volume_weighted_sum = sums[:volume_weighted_sum]
							prev_combined_volume = sums[:combined_volume]

							%{sums |
								volume_weighted_sum: prev_volume_weighted_sum + (rebased_path_volume * rebased_rate),
								combined_volume: prev_combined_volume + rebased_path_volume
							}
						false ->
							sums
					end

					sums[:volume_weighted_sum] / sums[:combined_volume]
			end

			def level2_rebase_pairs() do
				Map.reduce(market, [], fn (acc1, p2) ->
					case p2[base_address] == rebase_address do
						true ->
							Map.reduce(market, acc1, fn (acc2, p1) ->
								case (p1[base_address] == p2[quote_address] && base_address == p1[quote_address]) do
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
		end

	end


end
