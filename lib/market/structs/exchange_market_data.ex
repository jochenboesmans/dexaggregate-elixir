defmodule Market.ExchangeMarketData do
	@moduledoc """
		Data structure containing exchange-specific market data for a pair.
	"""

	@enforce_keys [:last_price, :current_bid, :current_ask, :base_volume, :quote_volume]
	defstruct(
		last_price: nil,
		current_bid: nil,
		current_ask: nil,
		base_volume: nil,
		quote_volume: nil
	)
end
