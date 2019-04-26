defmodule KyberFetcherTest do
	use ExUnit.Case, async: true
	alias MarketFetching.KyberFetcher, as: KF
	doctest KF

	describe "transform_currencies/1" do
		@describetag :transform_currencies
		test "#1: returns properly transformed data structure on realistic data" do
			sample_currencies =
				[
					%{
						"address" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
						"decimals" => 18,
						"id" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
						"name" => "Ethereum",
						"symbol" => "ETH"
					},
					%{
						"address" => "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
						"decimals" => 18,
						"id" => "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
						"name" => "Wrapped Ether",
						"reserves_dest" => ["0x57f8160e1c59D16C01BbE181fD94db4E56b60495"],
						"reserves_src" => ["0x57f8160e1c59D16C01BbE181fD94db4E56b60495"],
						"symbol" => "WETH"
					}
				]
			expected_result =
				%{
					"ETH" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
					"WETH" => "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
				}
			assert KF.transform_currencies(sample_currencies) == expected_result
		end
	end

	describe "fetch_and_decode/1" do
		@describetag :fetch_and_decode
		test "#1: returns a map with expected keys and values for currencies" do
			result = KF.fetch_and_decode("https://api.kyber.network/currencies")
			binary_keys = MapSet.new(["symbol", "address"])
			Enum.each(result, fn c ->
				Enum.each(binary_keys, fn k ->
					assert Map.has_key?(c, k)
					assert is_binary(c[k])
				end)
			end)
		end
		test "#2: returns a map with expected keys and values for market" do
			result = KF.fetch_and_decode("https://api.kyber.network/market")
			binary_keys = MapSet.new(["base_symbol", "quote_symbol"])
			number_keys = MapSet.new(["last_traded", "current_bid", "current_ask", "eth_24h_volume", "token_24h_volume"])
			Enum.each(result, fn p ->
				Enum.each(MapSet.union(number_keys, binary_keys), fn k ->
					assert Map.has_key?(p, k)
				end)
				Enum.each(number_keys, fn nk ->
					assert is_number(p[nk])
				end)
				Enum.each(binary_keys, fn bk ->
					assert is_binary(p[bk])
				end)
			end)
		end
	end

	describe "assemble_exchange_market/1" do
		@describetag :assemble_exchange_market
		test "#1: returns expected data structure format on realistic data" do
			sample_market =
				[
					%{
						"base_symbol" => "ETH",
						"current_ask" => 1,
						"current_bid" => 1,
						"eth_24h_volume" => 414.92872218052963,
						"last_traded" => 1,
						"pair" => "ETH_WETH",
						"past_24h_high" => 1,
						"past_24h_low" => 1,
						"quote_symbol" => "WETH",
						"timestamp" => 1556220941489,
						"token_24h_volume" => 414.92872218052963,
						"usd_24h_volume" => 68669.1907145455
					},
					%{
						"base_symbol" => "ETH",
						"current_ask" => 0.0015385576576022993,
						"current_bid" => 0.001525757417920522,
						"eth_24h_volume" => 108.04677201469775,
						"last_traded" => 0.001519580262382383,
						"pair" => "ETH_KNC",
						"past_24h_high" => 0.0015659792829957944,
						"past_24h_low" => 0.0014526952326232997,
						"quote_symbol" => "KNC",
						"timestamp" => 1556220941489,
						"token_24h_volume" => 72506.80040991471,
						"usd_24h_volume" => 17815.002306743016
					},
					%{
						"base_symbol" => "ETH",
						"current_ask" => 0.005877684503822772,
						"current_bid" => 0.005876612292041594,
						"eth_24h_volume" => 1289.8481971478866,
						"last_traded" => 0.005895361750450811,
						"pair" => "ETH_DAI",
						"past_24h_high" => 0.005995116298959469,
						"past_24h_low" => 0.005833206481640775,
						"quote_symbol" => "DAI",
						"timestamp" => 1556220941489,
						"token_24h_volume" => 219212.1253756595,
						"usd_24h_volume" => 213435.43743667478
					}
				]
			expected_result =
				%MarketFetching.ExchangeMarket{
					exchange: :kyber,
					market: [
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 414.92872218052963,
								current_ask: 1,
								current_bid: 1,
								exchange: :kyber,
								last_price: 1,
								quote_volume: 414.92872218052963
							},
							quote_address: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
							quote_symbol: "WETH"
						},
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 108.04677201469775,
								current_ask: 0.0015385576576022993,
								current_bid: 0.001525757417920522,
								exchange: :kyber,
								last_price: 0.001519580262382383,
								quote_volume: 72506.80040991471
							},
							quote_address: "0xdd974d5c2e2928dea5f71b9825b8b646686bd200",
							quote_symbol: "KNC"
						},
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 1289.8481971478866,
								current_ask: 0.005877684503822772,
								current_bid: 0.005876612292041594,
								exchange: :kyber,
								last_price: 0.005895361750450811,
								quote_volume: 219212.1253756595
							},
							quote_address: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
							quote_symbol: "DAI"
						}
					]
				}
			assert expected_result == KF.assemble_exchange_market(sample_market)
		end
	end
end