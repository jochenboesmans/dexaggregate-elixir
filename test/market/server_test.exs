defmodule Test.Dexaggregatex.Market.Server do
	@moduledoc false
	use ExUnit.Case, async: true

	alias Dexaggregatex.Market.Structs.{Market, LastUpdate, ExchangeMarketData}
	alias Dexaggregatex.Market.Structs.Pair, as: MarketPair
	alias Dexaggregatex.MarketFetching.Structs.{ExchangeMarket, PairMarketData}
	alias Dexaggregatex.MarketFetching.Structs.Pair, as: MarketFetchingPair
	import Dexaggregatex.Market.Util

	alias Dexaggregatex.Market.Server
	doctest Server

	describe "add_pair/2" do
		@describetag :add_pair
		test "#1: MarketFetchingPair not yet present in market." do
			sm = %Market{pairs: %{}}
			ba = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
			qa = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
			bs = "ETH"
			qs = "DAI"
			lp = 1
			cb = 2
			ca = 3
			bv = 4
			p_id = pair_id(ba, qa)
			smfp =
				%MarketFetchingPair{
					base_address: ba,
					quote_address: qa,
					base_symbol: bs,
					quote_symbol: qs,
					market_data: %PairMarketData{
						exchange: :kyber,
						last_price: lp,
						current_bid: cb,
						current_ask: ca,
						base_volume: bv,
					}
				}
			{update_status, updated_market, _updated_pair} = Server.add_pair(sm, smfp)
			assert update_status == :update
			assert Enum.count(updated_market.pairs) == 1
			assert Enum.count(updated_market.pairs[p_id].market_data) == 1
		end
	end
end
