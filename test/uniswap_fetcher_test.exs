defmodule UniswapFetcherTest do
	use ExUnit.Case, async: true
	alias MarketFetching.UniswapFetcher, as: UF
	doctest UF

	describe "transform_volume/1" do
		test "#1: returns properly transformed volume for realistic value" do
			sample_value = "45704016300115740247"
			assert UF.transform_volume(sample_value) === 45.70401630011574
		end
	end

	describe "fetch_and_decode/1" do
		test "#1: returns empty map on unexisting pair" do
			assert UF.fetch_and_decode("https://uniswap-analytics.appspot.com/api/v1/ticker?exchangeAddress=stupidunexistingaddress") == nil
		end
		test "#2: returns a map with expected keys and values on existing pair" do
			dai_exchange_address = "0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14"
			result = UF.fetch_and_decode("https://uniswap-analytics.appspot.com/api/v1/ticker?exchangeAddress=#{dai_exchange_address}")
			expected_keys = MapSet.new(["price", "lastTradePrice", "tradeVolume", "weightedAvgPrice"])
			Enum.each(expected_keys, fn k ->
				assert Map.has_key?(result, k)
				assert is_binary(result[k]) || is_float(result[k])
			end)
		end
	end

	describe "fetch_market/0" do
		test "#1: returns a list with a length corresponding to exchange_addresses/0" do
			assert Enum.count(UF.exchange_addresses()) === Enum.count(UF.fetch_market())
		end
	end

	describe "assemble_exchange_market/1" do
		test "#1: returns expected data structure format on realistic data" do
			sample_market =
				[
					{"BAT",
						%{
							"count" => 340,
							"endTime" => 1556201011,
							"erc20Liquidity" => "718108096158945263830197",
							"ethLiquidity" => "1876678150446206051043",
							"highPrice" => 406.06664693048043,
							"invPrice" => 0.00261336442310605,
							"lastTradeErc20Qty" => "-612000000000000000000",
							"lastTradeEthQty" => "1538426475705335228",
							"lastTradePrice" => 399.3447679713733,
							"lowPrice" => 363.78431917111135,
							"price" => 382.64850900949915,
							"priceChange" => 15.69469700952726,
							"priceChangePercent" => 0.040981319962679466,
							"startTime" => 1556114611,
							"symbol" => "BAT",
							"theme" => "#ff5000",
							"tradeVolume" => "695211032298252559271",
							"weightedAvgPrice" => 385.0626103016363
						}},
					{"DAI",
						%{
							"count" => 324,
							"endTime" => 1556201636,
							"erc20Liquidity" => "1371154458275834750413362",
							"ethLiquidity" => "8134709314961982749472",
							"highPrice" => 172.5126311048589,
							"invPrice" => 0.005932744677934399,
							"lastTradeErc20Qty" => "1147994047678062846",
							"lastTradeEthQty" => "-6727482077018471",
							"lastTradePrice" => 170.13037603623073,
							"lowPrice" => 164.27230516199367,
							"price" => 168.55604855528176,
							"priceChange" => 1.5815818810501128,
							"priceChangePercent" => 0.009383508599100965,
							"startTime" => 1556115236,
							"symbol" => "DAI",
							"theme" => "#fdc134",
							"tradeVolume" => "2004077810061510209493",
							"weightedAvgPrice" => 169.1930143375401
						}},
					{"MKR",
						%{
							"count" => 263,
							"endTime" => 1556201281,
							"erc20Liquidity" => "3114176475083061426031",
							"ethLiquidity" => "10521506430177158420863",
							"highPrice" => 0.31285514500925693,
							"invPrice" => 3.378583877426705,
							"lastTradeErc20Qty" => "-293324742123835466",
							"lastTradeEthQty" => "1000000000000000000",
							"lastTradePrice" => 0.29423654071923716,
							"lowPrice" => 0.28582903009911015,
							"price" => 0.29598199609051856,
							"priceChange" => -0.0018319842061981784,
							"priceChangePercent" => -0.00618892492662026,
							"startTime" => 1556114881,
							"symbol" => "MKR",
							"theme" => "#1abc9c",
							"tradeVolume" => "3826066380503804456541",
							"weightedAvgPrice" => 0.2947299245761119
						}},
					{"SPANK",
						%{
							"count" => 26,
							"endTime" => 1556201206,
							"erc20Liquidity" => "2695167298358714610119080",
							"ethLiquidity" => "206166677738072748049",
							"highPrice" => 13004.678100463427,
							"invPrice" => 7.649494629280445e-5,
							"lastTradeErc20Qty" => "-5000000000000000000000",
							"lastTradeEthQty" => "392968836995110640",
							"lastTradePrice" => 12788.17253374482,
							"lowPrice" => 11923.717254505107,
							"price" => 13072.759031325259,
							"priceChange" => 180.52367040909303,
							"priceChangePercent" => 0.014373333044797954,
							"startTime" => 1556114806,
							"symbol" => "SPANK",
							"theme" => "#00b4f4",
							"tradeVolume" => "45704016300115740247",
							"weightedAvgPrice" => 12494.17454088414
						}},
					{"ZRX",
						%{
							"count" => 32,
							"endTime" => 1556201167,
							"erc20Liquidity" => "183214620681062238120580",
							"ethLiquidity" => "318297635618775369365",
							"highPrice" => 584.5786409273702,
							"invPrice" => 0.0017372938602583689,
							"lastTradeErc20Qty" => "-150000000000000000000",
							"lastTradeEthQty" => "262215876148204213",
							"lastTradePrice" => 570.8244791079059,
							"lowPrice" => 553.1231539068882,
							"price" => 575.607859370021,
							"priceChange" => -5.642479730518403,
							"priceChangePercent" => -0.009803970647187724,
							"startTime" => 1556114767,
							"symbol" => "ZRX",
							"theme" => "#302c2c",
							"tradeVolume" => "17787609702056057293",
							"weightedAvgPrice" => 567.2967081982425
						}}
				]
			expected_result =
				%MarketFetching.ExchangeMarket{
					exchange: :uniswap,
					market: [
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 695.2110322982526,
								current_ask: 0.00261336442310605,
								current_bid: 0.00261336442310605,
								exchange: :uniswap,
								last_traded: 0.0025041019194514255,
								quote_volume: 267699.7748072603
							},
							quote_address: "0x0d8775f648430679a709e98d2b0cb6250d2887ef",
							quote_symbol: "BAT"
						},
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 2004.0778100615103,
								current_ask: 0.005932744677934399,
								current_bid: 0.005932744677934399,
								exchange: :uniswap,
								last_traded: 0.005877845116777038,
								quote_volume: 339075.96565128304
							},
							quote_address: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
							quote_symbol: "DAI"
						},
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 3826.066380503805,
								current_ask: 3.378583877426705,
								current_bid: 3.378583877426705,
								exchange: :uniswap,
								last_traded: 3.398626144650769,
								quote_volume: 1127.6562557490838
							},
							quote_address: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
							quote_symbol: "MKR"
						},
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 45.70401630011574,
								current_ask: 7.649494629280445e-5,
								current_bid: 7.649494629280445e-5,
								exchange: :uniswap,
								last_traded: 7.819725589103897e-5,
								quote_volume: 571033.9568730599
							},
							quote_address: "0x42d6622dece394b54999fbd73d108123806f6a18",
							quote_symbol: "SPANK"
						},
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 17.78760970205606,
								current_ask: 0.0017372938602583689,
								current_bid: 0.0017372938602583689,
								exchange: :uniswap,
								last_traded: 0.0017518519905852967,
								quote_volume: 10090.852430691524
							},
							quote_address: "0xe41d2489571d322189246dafa5ebde1f4699f498",
							quote_symbol: "ZRX"
						}
					]
				}
			assert expected_result == UF.assemble_exchange_market(sample_market)
		end
	end
end