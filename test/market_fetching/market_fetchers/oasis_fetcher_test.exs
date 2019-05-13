defmodule Test.MarketFetching.OasisFetcher do

	use ExUnit.Case, async: true

	alias MarketFetching.OasisFetcher, as: OF

	doctest OF

	describe "assemble_exchange_market/1" do
		@describetag :assemle_exchange_market
		test "#1: returns expected data structure format on realistic data" do
			sample_market =
				[
					%{
						"active" => true,
						"ask" => "3.35990000",
						"bid" => "3.10000000",
						"high" => "3.35990000",
						"last" => "3.10000000",
						"low" => "3.05000000",
						"pair" => "MKR/ETH",
						"price" => "3.10399460",
						"vol" => "44.27666233"
					},
					%{
						"active" => true,
						"ask" => "575.73999000",
						"bid" => "10.00010000",
						"high" => "1287.24112000",
						"last" => "575.73999000",
						"low" => "480.00000000",
						"pair" => "MKR/DAI",
						"price" => "495.05876980",
						"vol" => "67.35609292"
					},
					%{
						"active" => true,
						"ask" => "157.00000000",
						"bid" => "156.47616500",
						"high" => "160.00000000",
						"last" => "157.00000000",
						"low" => "153.11000000",
						"pair" => "ETH/DAI",
						"price" => "156.46627936",
						"vol" => "1573.69670298"
					}
				]
			expected_result =
				%MarketFetching.ExchangeMarket{
					exchange: :oasis,
					market: [
						%MarketFetching.Pair{
							base_address: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
							base_symbol: "DAI",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 1573.69670298,
								current_ask: 157.0,
								current_bid: 156.476165,
								exchange: :oasis,
								last_price: 157.0,
							},
							quote_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							quote_symbol: "ETH"
						},
						%MarketFetching.Pair{
							base_address: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
							base_symbol: "DAI",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 67.35609292,
								current_ask: 575.73999,
								current_bid: 10.0001,
								exchange: :oasis,
								last_price: 575.73999,
							},
							quote_address: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
							quote_symbol: "MKR"
						},
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 44.27666233,
								current_ask: 3.3599,
								current_bid: 3.1,
								exchange: :oasis,
								last_price: 3.1,
							},
							quote_address: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
							quote_symbol: "MKR"
						},
					]
				}
			assert expected_result == OF.assemble_exchange_market(sample_market)
		end
	end
end