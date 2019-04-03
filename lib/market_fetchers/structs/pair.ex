defmodule MarketFetchers.Structs.Pair do
  alias MarketFetchers.Structs.PairMarketData
  @moduledoc false

  @enforce_keys [:base_symbol, :quote_symbol, :base_address, :quote_address, :market_data]

  defstruct(
    base_symbol: nil,
    quote_symbol: nil,
    quote_address: nil,
    base_address: nil,
    market_data: %PairMarketData{
      last_traded: nil,
      current_bid: nil,
      current_ask: nil,
      base_volume: nil,
      quote_volume: nil
    }
  )
end
