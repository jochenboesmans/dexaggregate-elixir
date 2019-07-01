defmodule Test.Dexaggregatex.Market.Rebasing do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Dexaggregatex.Market.Structs.{Pair, ExchangeMarketData}
  alias Dexaggregatex.Market.Rebasing

  doctest Rebasing

  @dai_address "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
  @eth_address "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"

  describe "volume_weighted_spread_average/2" do
    @describetag :volume_weighted_spread_average
    test "#1: basic pair with 0 values as market data." do
      sample_pair = %Pair{
        base_symbol: "DAI",
        quote_symbol: "ETH",
        base_address: @dai_address,
        quote_address: @eth_address,
        market_data: %{
          :oasis => %ExchangeMarketData{
            last_price: 0,
            current_bid: 0,
            current_ask: 0,
            base_volume: 0,
            timestamp: :os.system_time(:millisecond)
          }
        }
      }

      result = Rebasing.volume_weighted_spread_average(sample_pair)
      assert result == 0
    end
  end
end
