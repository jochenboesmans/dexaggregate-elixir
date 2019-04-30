defmodule Market.RebasingTest do
	use ExUnit.Case, async: true
	alias Market.Rebasing, as: Rebasing
	import Market.Util
	doctest Rebasing

	alias Market.Pair, as: Pair
	alias Market.ExchangeMarketData, as: ExchangeMarketData

	describe "volume_weighted_spread_average/2" do
		@describetag :volume_weighted_spread_average
		test "#1: pair doesn't exist in market" do
			dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
			eth_address = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
			bat_address = "0x0d8775f648430679a709e98d2b0cb6250d2887ef"
			sample_pair = %Pair{
				base_symbol: "DAI",
				quote_symbol: "ETH",
				base_address: dai_address,
				quote_address: eth_address,
				market_data: %{
					:oasis => %ExchangeMarketData{
						last_price: 0,
						current_bid: 0,
						current_ask: 0,
						base_volume: 0,
						quote_volume: 0,
					}
				}
			}
			sample_market = %{Market.Util.pair_id(eth_address, bat_address) => %Pair{
				base_symbol: "ETH",
				quote_symbol: "BAT",
				base_address: eth_address,
				quote_address: bat_address,
				market_data: %{
					:oasis => %ExchangeMarketData{
						last_price: 0,
						current_bid: 0,
						current_ask: 0,
						base_volume: 0,
						quote_volume: 0,
					}
				}
			}}
			result = Rebasing.volume_weighted_spread_average(sample_pair, sample_market)
			assert result == 0
		end
	end

	describe "update_sums_level1/5" do
		@describetag :update_sums_level1
		test "#1: returns sums on inexisting immediate_rebase_pair" do
			sums = %{volume_weighted_sum: 1234, combined_volume: 5678}
			r = Rebasing.update_sums_level1(sums, nil, nil, nil, nil)
			assert r == sums
		end
		test "#2: correctly updates sums on existing immediate_rebase_pair" do
			immediate_rebase_pair = %Pair{
				base_symbol: "DAI",
				quote_symbol: "ETH",
				quote_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
				base_address: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
				market_data: %ExchangeMarketData{
					last_price: 200,
					current_bid: 195,
					current_ask: 205,
					base_volume: 100_000,
					quote_volume: 5_000
				}
			}
			original_pair = %Pair{
				base_symbol: "ETH",
				quote_symbol: "BAT",
				quote_address: "0x0d8775f648430679a709e98d2b0cb6250d2887ef",
				base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
				market_data: %ExchangeMarketData{
					last_price: 0.0023,
					current_bid: 0.0022,
					current_ask: 0.0024,
					base_volume: 5_000,
					quote_volume: 300_000
				}
			}
			sample_market = %{
				pair_id(immediate_rebase_pair) => immediate_rebase_pair,
				pair_id(original_pair) => original_pair
			}
			assert false
		end
	end

end