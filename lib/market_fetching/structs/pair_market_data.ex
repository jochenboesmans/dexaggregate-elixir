defmodule MarketFetchers.PairMarketData do
  @moduledoc """
		Data structure for newly fetched market data specific to a pair on an exchange.
  """

  @enforce_keys [:exchange, :last_traded, :current_bid, :current_ask, :base_volume, :quote_volume]

  defstruct(
    exchange: nil,
    last_traded: nil,
    current_bid: nil,
    current_ask: nil,
    base_volume: nil,
    quote_volume: nil,
  )
end
