defmodule MarketFetching.PairMarketData do
  @moduledoc """
		Data structure for newly fetched market data specific to a pair on an exchange.
  """

  @enforce_keys [:exchange, :last_price, :current_bid, :current_ask, :base_volume]
  defstruct(
    exchange: nil,
    last_price: nil,
    current_bid: nil,
    current_ask: nil,
    base_volume: nil
  )
end
