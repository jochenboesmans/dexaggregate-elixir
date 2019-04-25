defmodule RadarFetcherTest do
	use ExUnit.Case, async: true
	alias MarketFetching.RadarFetcher, as: RF
	doctest RF

	describe "fetch_and_decode/1" do
		test "#1: returns map with expected format" do
			result = RF.fetch_and_decode("https://api.radarrelay.com/v2/markets?include=base,ticker,stats")
			expected_keys = MapSet.new(["id", "baseTokenAddress", "quoteTokenAddress", "ticker", "stats"])
			expected_ticker_keys = MapSet.new(["price", "bestBid", "bestAsk"])
			expected_stats_keys = MapSet.new(["volume24Hour"])
			Enum.each(result, fn p ->
				Enum.each(expected_keys, fn k ->
					assert Map.has_key?(p, k)
					Enum.each(expected_ticker_keys, fn tk ->
						assert Map.has_key?(p["ticker"], tk)
						assert is_binary(p["ticker"][tk])
					end)
					Enum.each(expected_stats_keys, fn sk ->
						assert Map.has_key?(p["stats"], sk)
						assert is_binary(p["stats"][sk])
					end)
				end)
			end)
		end
	end

	describe "assemble_exchange_market/1" do
		test "#1: returns expected data structure format on realistic data" do
			sample_market =
				[
					%{
						"active" => 1,
						"baseTokenAddress" => "0x514910771af9ca656af840dff83e8264ecf986ca",
						"baseTokenDecimals" => 18,
						"displayName" => "LINK/WETH",
						"id" => "LINK-WETH",
						"maxOrderSize" => "1000000000",
						"minOrderSize" => "0.01991040",
						"quoteIncrement" => 8,
						"quoteTokenAddress" => "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
						"quoteTokenDecimals" => 18,
						"score" => 37.1,
						"stats" => %{
							"baseTokenAvailable" => "9596.17009648613",
							"numAsksWithinRange" => 4,
							"numBidsWithinRange" => 2,
							"percentChange24Hour" => "0",
							"quoteTokenAvailable" => "29.421489153832297",
							"volume24Hour" => "0"
						},
						"ticker" => %{
							"bestAsk" => "0.0030294985822278274",
							"bestBid" => "0.0028898874051844162",
							"price" => "0.0030600755391650934",
							"size" => "4",
							"spreadPercentage" => "0.046083922224761084",
							"timestamp" => 1554774469,
							"transactionHash" => "0x74423add2b5b8fb3f3de43a9e8dbeed571a4161c8c33dce6571596f8aaa6a948"
						}
					},
					%{
						"active" => 1,
						"baseTokenAddress" => "0x0e0989b1f9b8a38983c2ba8053269ca62ec9b195",
						"baseTokenDecimals" => 8,
						"displayName" => "POE/WETH",
						"id" => "POE-WETH",
						"maxOrderSize" => "1000000000",
						"minOrderSize" => "1.80468353",
						"quoteIncrement" => 8,
						"quoteTokenAddress" => "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
						"quoteTokenDecimals" => 18,
						"score" => 35.95,
						"stats" => %{
							"baseTokenAvailable" => "353025.24485331",
							"numAsksWithinRange" => 3,
							"numBidsWithinRange" => 3,
							"percentChange24Hour" => "0",
							"quoteTokenAvailable" => "17.545970623238606",
							"volume24Hour" => "0"
						},
						"ticker" => %{
							"bestAsk" => "0.00003469316486223732",
							"bestBid" => "0.000031763887843523324",
							"price" => "0.00003376066373974297",
							"size" => "0.010128199121922893",
							"spreadPercentage" => "0.08443383676138594",
							"timestamp" => 1550703136,
							"transactionHash" => "0xa9eb35feb32cba36760b1933809013fb169d12467536b6765a160b037fa839f2"
						}
					}
				]
			expected_result =
				%MarketFetching.ExchangeMarket{
					exchange: :radar,
					market: [
						%MarketFetching.Pair{
							base_address: "0x514910771af9ca656af840dff83e8264ecf986ca",
							base_symbol: "WETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 0.0,
								current_ask: 0.0030294985822278274,
								current_bid: 0.0028898874051844162,
								exchange: :radar,
								last_traded: 0.0030600755391650934,
								quote_volume: nil
							},
							quote_address: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
							quote_symbol: "LINK"
						},
						%MarketFetching.Pair{
							base_address: "0x0e0989b1f9b8a38983c2ba8053269ca62ec9b195",
							base_symbol: "WETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 0.0,
								current_ask: 3.469316486223732e-5,
								current_bid: 3.1763887843523324e-5,
								exchange: :radar,
								last_traded: 3.376066373974297e-5,
								quote_volume: nil
							},
							quote_address: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
							quote_symbol: "POE"
						}
					]
				}
			assert expected_result == RF.assemble_exchange_market(sample_market)
		end
	end
end