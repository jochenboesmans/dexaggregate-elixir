defmodule IdexFetcherTest do
	use ExUnit.Case, async: true
	alias MarketFetching.MarketFetchers.IdexFetcher, as: IF
	doctest IF

	describe "fetch_and_decode/1" do
		@describetag :fetch_and_decode
		test "#1: returns a map with expected keys and values for currencies" do
			result = IF.fetch_and_decode("https://api.idex.market/returnCurrencies")
			binary_keys = MapSet.new(["address"])
			Enum.each(result, fn {_token, v} ->
				Enum.each(binary_keys, fn k ->
					assert Map.has_key?(v, k)
					assert is_binary(v[k])
				end)
			end)
		end
		test "#2: returns a map with expected keys and values for market" do
			result = IF.fetch_and_decode("https://api.idex.market/returnTicker")
			binary_keys = MapSet.new(["last", "highestBid", "lowestAsk", "baseVolume", "quoteVolume"])
			Enum.each(result, fn {_token, v} ->
				Enum.each(binary_keys, fn k ->
					assert Map.has_key?(v, k)
					assert is_binary(v[k])
				end)
			end)
		end
	end

	describe "transform_currencies/1" do
		@describetag :transform_currencies
		test "#1: correctly transforms realistic data" do
			sample_currencies =
				%{
					"ETH" => %{
						"address" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
						"decimals" => 18,
						"name" => "Ether"
					}
				}
			expected_result = %{"ETH" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"}
			assert IF.transform_currencies(sample_currencies) == expected_result
		end
	end

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
						"quoteVolume" => "403.55108905"
					},
					"ETH_PAR" => %{
						"baseVolume" => "0.660044285292758433",
						"high" => "0.00000099",
						"highestBid" => "0.000000850000000001",
						"last" => "0.00000095111111111",
						"low" => "0.00000085",
						"lowestAsk" => "0.0000015",
						"percentChange" => "11.89542484",
						"quoteVolume" => "696568.942358119114626039"
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
								base_volume: 0.15303379733935618,
								current_ask: 4.77999754000064e-4,
								current_bid: 3.794906505e-4,
								exchange: :idex,
								last_traded: 3.79217902e-4,
								quote_volume: 403.55108905
							},
							quote_address: "0xa645264c5603e96c3b0b078cdab68733794b0a71",
							quote_symbol: "MYST"
						},
						%MarketFetching.Pair{
							base_address: "0x0000000000000000000000000000000000000000",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 0.6600442852927584,
								current_ask: 1.5e-6,
								current_bid: 8.50000000001e-7,
								exchange: :idex,
								last_traded: 9.5111111111e-7,
								quote_volume: 696568.9423581191
							},
							quote_address: "0x1beef31946fbbb40b877a72e4ae04a8d1a5cee06",
							quote_symbol: "PAR"
						}
					]
				}
			assert expected_result == IF.assemble_exchange_market(sample_market)
		end
	end
end