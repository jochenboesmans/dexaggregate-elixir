defmodule TokenstoreFetcherTest do
	use ExUnit.Case, async: true
	alias MarketFetching.MarketFetchers.TokenstoreFetcher, as: TF
	doctest TF

	describe "fetch_and_decode/1" do
		@describetag :fetch_and_decode
		test "#1: returns a map with expected keys and values" do
			result = TF.fetch_and_decode("https://v1-1.api.token.store/ticker")
			binary_keys = MapSet.new(["symbol", "tokenAddr"])
			number_keys = MapSet.new(["last", "bid", "ask", "baseVolume", "quoteVolume"])
			Enum.each(result, fn {_p, v} ->
				Enum.each(MapSet.union(binary_keys, number_keys), fn k ->
					assert Map.has_key?(v, k)
				end)
				Enum.each(binary_keys, fn bk ->
					assert is_binary(v[bk])
				end)
				Enum.each(number_keys, fn nk ->
					assert is_number(v[nk]) || v[nk] == nil
				end)
			end)
		end
	end

	describe "assemble_exchange_market/1" do
		@describetag :assemble_exchange_market
		test "#1: returns expected data structure format on realistic data" do
			sample_market =
				%{
					"ETH_DAI" => %{
						"ask" => 0.008879112,
						"baseVolume" => 0.0017758224,
						"bid" => 0.008879112,
						"last" => nil,
						"percentChange" => 0,
						"quoteVolume" => 0.2,
						"symbol" => "DAI",
						"tokenAddr" => "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
					},
					"ETH_DARK" => %{
						"ask" => 1.99999e-17,
						"baseVolume" => 1.99999e-5,
						"bid" => 1.99999e-17,
						"last" => nil,
						"percentChange" => 0,
						"quoteVolume" => 1000000000000,
						"symbol" => "DARK",
						"tokenAddr" => "0x27611ae3af6f65753e8cac0ae5e53ef37ca5d319"
					},
					"ETH_HXG" => %{
						"ask" => 3.0e-19,
						"baseVolume" => 3.0e-6,
						"bid" => 3.0e-19,
						"last" => nil,
						"percentChange" => 0,
						"quoteVolume" => 10000000000000,
						"symbol" => "HXG",
						"tokenAddr" => "0xb5335e24d0ab29c190ab8c2b459238da1153ceba"
					}
				}
			expected_result =
				%MarketFetching.ExchangeMarket{
					exchange: :tokenstore,
					market: [
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 0.0017758224,
								current_ask: 0.008879112,
								current_bid: 0.008879112,
								exchange: :tokenstore,
								last_traded: nil,
								quote_volume: 0.2
							},
							quote_address: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
							quote_symbol: "DAI"
						},
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 1.99999e-5,
								current_ask: 1.99999e-17,
								current_bid: 1.99999e-17,
								exchange: :tokenstore,
								last_traded: nil,
								quote_volume: 1000000000000
							},
							quote_address: "0x27611ae3af6f65753e8cac0ae5e53ef37ca5d319",
							quote_symbol: "DARK"
						},
						%MarketFetching.Pair{
							base_address: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
							base_symbol: "ETH",
							market_data: %MarketFetching.PairMarketData{
								base_volume: 3.0e-6,
								current_ask: 3.0e-19,
								current_bid: 3.0e-19,
								exchange: :tokenstore,
								last_traded: nil,
								quote_volume: 10000000000000
							},
							quote_address: "0xb5335e24d0ab29c190ab8c2b459238da1153ceba",
							quote_symbol: "HXG"
						}
					]
				}
			assert expected_result == TF.assemble_exchange_market(sample_market)
		end
	end
end