defmodule OasisFetcherTest do
	use ExUnit.Case, async: true
	alias MarketFetching.OasisFetcher, as: OF
	doctest OF

	describe "fetch_and_decode/1" do
		@describetag :fetch_and_decode
		test "#1: returns empty map on unexisting pair" do
			assert OF.fetch_and_decode("http://api.oasisdex.com/v1/markets/MKR/MKR") == %{}
		end
		test "#2: returns a map with expected keys and values on existing pair" do
			result = OF.fetch_and_decode("http://api.oasisdex.com/v1/markets/MKR/DAI")
			expected_keys = MapSet.new(["pair", "price", "last", "vol", "ask", "bid", "low", "high"])
			Enum.each(expected_keys, fn k ->
				assert is_binary(result[k])
				assert Map.has_key?(result, k)
			end)
		end
	end

	describe "fetch_market/0" do
		@describetag :fetch_market
		test "#1: returns a list with a length corresponding to pairs/0" do
			assert Enum.count(OF.pairs()) === Enum.count(OF.fetch_market())
		end
	end

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
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 44.27666233,
								current_ask: 3.3599,
								current_bid: 3.1,
								exchange: :oasis,
								last_price: 3.1,
								quote_volume: nil
							},
							quote_address: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
							quote_symbol: "MKR"
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
								quote_volume: nil
							},
							quote_address: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
							quote_symbol: "MKR"
						},
						%MarketFetching.Pair{
							base_address: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
							base_symbol: "DAI",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 1573.69670298,
								current_ask: 157.0,
								current_bid: 156.476165,
								exchange: :oasis,
								last_price: 157.0,
								quote_volume: nil
							},
							quote_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							quote_symbol: "ETH"
						}
					]
				}
			assert expected_result == OF.assemble_exchange_market(sample_market)
		end
	end
end