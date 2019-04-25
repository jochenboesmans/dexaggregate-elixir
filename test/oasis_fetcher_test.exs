defmodule OasisFetcherTests do
	use ExUnit.Case, async: true
	alias MarketFetching.MarketFetchers.OasisFetcher, as: OF
	doctest OF

	setup do
		{:ok, pid} = OF.start_link(nil)
		{:ok, pid: pid}
	end

	describe "transform_rate/1" do
		@describetag :transform_rate

		test "#1: returns nil for nil" do
			assert OF.transform_rate(nil) == nil
		end
		test "#2: returns nil for \"\"" do
			assert OF.transform_rate("") == nil
		end
		test "#3: returns a float value containing the inverse of the value of the passed in string" do
			assert OF.transform_rate("608.46366185") === 0.0016434835187356227
		end
		test "#4: returns the inverse of the passed in value for a float" do
			assert OF.transform_rate(608.46366185) === 0.0016434835187356227
		end
		test "#5: returns the inverse of the passed in value for an integer" do
			assert OF.transform_rate(608) === 0.001644736842105263
		end
	end

	describe "fetch_and_decode/1" do
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
		test "#1: returns a list with a length corresponding to pairs/0" do
			assert Enum.count(OF.pairs()) === Enum.count(OF.fetch_market())
		end
	end

	describe "assemble_exchange_market/1" do
		test "#1: returns expected data structure format on realistic data" do
			sample_market =
				[
					%{
						"active" => true,
						"ask" => "3.45000000",
						"bid" => "3.18000000",
						"high" => "3.40630000",
						"last" => "3.26000000",
						"low" => "3.25000000",
						"pair" => "MKR/ETH",
						"price" => "3.30035196",
						"vol" => "57.81307278"
					},
					%{
						"active" => true,
						"ask" => "587.96805657",
						"bid" => "555.90008474",
						"high" => "605.51457020",
						"last" => "587.96805657",
						"low" => "557.17242614",
						"pair" => "MKR/DAI",
						"price" => "566.58137230",
						"vol" => "41.85309481"
					},
					%{
						"active" => true,
						"ask" => "169.76700000",
						"bid" => "168.06000000",
						"high" => "172.83595688",
						"last" => "168.14000000",
						"low" => "166.68000000",
						"pair" => "ETH/DAI",
						"price" => "170.21315075",
						"vol" => "1341.35495505"
					}
				]
			expected_result =
				%MarketFetching.ExchangeMarket{
					exchange: :oasis,
					market: [
						%MarketFetching.Pair{
							base_address: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
							base_symbol: "MKR",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 0.01729712592522746,
								current_ask: 0.2898550724637681,
								current_bid: 0.31446540880503143,
								exchange: :oasis,
								last_traded: 0.3067484662576687,
								quote_volume: nil
							},
							quote_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							quote_symbol: "ETH"
						},
						%MarketFetching.Pair{
							base_address: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
							base_symbol: "MKR",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 0.02389309570868506,
								current_ask: 0.0017007726675385226,
								current_bid: 0.0017988844172738521,
								exchange: :oasis,
								last_traded: 0.0017007726675385226,
								quote_volume: nil
							},
							quote_address: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
							quote_symbol: "DAI"
						},
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 7.455148215877909e-4,
								current_ask: 0.005890426290150619,
								current_bid: 0.005950255861002023,
								exchange: :oasis,
								last_traded: 0.005947424765076722,
								quote_volume: nil
							},
							quote_address: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
							quote_symbol: "DAI"
						}
					]
				}
			assert expected_result == OF.assemble_exchange_market(sample_market)
		end
	end


end