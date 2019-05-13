defmodule Test.MarketFetching.IdexFetcher do

	use ExUnit.Case, async: true

	alias MarketFetching.IdexFetcher, as: IF

	doctest IF

	describe "assemble_exchange_market/1" do
		@describetag :assemble_exchange_market
		test "#1: returns expected data structure format on realistic data" do
			sample_market =
				%{
					"ETH_MYST" => %{
						"baseVolume" => "0.153033797339356173",
						"high" => "0.000379217902",
						"highestBid" => "0.0003794906505",
						"last" => "0.000379217902",
						"low" => "0.000379217902",
						"lowestAsk" => "0.000477999754000064",
						"percentChange" => "0",
					},
					"ETH_PAR" => %{
						"baseVolume" => "0.660044285292758433",
						"high" => "0.00000099",
						"highestBid" => "0.000000850000000001",
						"last" => "0.00000095111111111",
						"low" => "0.00000085",
						"lowestAsk" => "0.0000015",
						"percentChange" => "11.89542484",
					}
				}
			expected_result =
				%MarketFetching.ExchangeMarket{
					exchange: :idex,
					market: [
						%MarketFetching.Pair{
							base_address: "0x0000000000000000000000000000000000000000",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 0.6600442852927584,
								current_ask: 1.5e-6,
								current_bid: 8.50000000001e-7,
								exchange: :idex,
								last_price: 9.5111111111e-7,
							},
							quote_address: "0x1beef31946fbbb40b877a72e4ae04a8d1a5cee06",
							quote_symbol: "PAR"
						},
						%MarketFetching.Pair{
							base_address: "0x0000000000000000000000000000000000000000",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 0.15303379733935618,
								current_ask: 4.77999754000064e-4,
								current_bid: 3.794906505e-4,
								exchange: :idex,
								last_price: 3.79217902e-4,
							},
							quote_address: "0xa645264c5603e96c3b0b078cdab68733794b0a71",
							quote_symbol: "MYST"
						},
					]
				}
			assert expected_result == IF.assemble_exchange_market(sample_market)
		end
	end
end