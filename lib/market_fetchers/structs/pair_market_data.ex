defmodule PairMarketData do
  @moduledoc false

  @enforce_keys [:last_traded, :current_bid, :current_ask, :base_volume, :quote_volume]

  defstruct(
    last_traded: nil,
    current_bid: nil,
    current_ask: nil,
    base_volume: nil,
    quote_volume: nil
  )
end
