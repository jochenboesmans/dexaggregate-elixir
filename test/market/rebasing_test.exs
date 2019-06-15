defmodule Test.Dexaggregatex.Market.Rebasing do
	use ExUnit.Case, async: true

	import Dexaggregatex.Market.Util
	alias Dexaggregatex.Market.Structs.{Pair, ExchangeMarketData}
	alias Dexaggregatex.Market.Rebasing

	doctest Rebasing

	@dai_address "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
	@eth_address "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	@bat_address "0x0d8775f648430679a709e98d2b0cb6250d2887ef"

	describe "volume_weighted_spread_average/2" do
		@describetag :volume_weighted_spread_average
		test "#1: pair doesn't exist in market" do
			sample_pair = %Pair{
				base_symbol: "DAI",
				quote_symbol: "ETH",
				base_address: @dai_address,
				quote_address: @eth_address,
				market_data: %{
					:oasis => %ExchangeMarketData{
						last_price: 0,
						current_bid: 0,
						current_ask: 0,
						base_volume: 0,
						timestamp: 0
					}
				}
			}
			sample_market = %{pair_id(@eth_address, @bat_address) => %Pair{
				base_symbol: "ETH",
				quote_symbol: "BAT",
				base_address: @eth_address,
				quote_address: @bat_address,
				market_data: %{
					:oasis => %ExchangeMarketData{
						last_price: 0,
						current_bid: 0,
						current_ask: 0,
						base_volume: 0,
						timestamp: 0
					}
				}
			}}
			result = Rebasing.volume_weighted_spread_average(sample_pair, sample_market)
			assert result == 0
		end
	end

end