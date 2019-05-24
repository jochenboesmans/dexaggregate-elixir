defmodule MarketFetching.Pair do
	@moduledoc """
		Data structure for newly fetched data specific to a pair on an exchange.
	"""
  @enforce_keys [:base_symbol, :quote_symbol, :base_address, :quote_address, :market_data]
  defstruct(
    base_symbol: nil,
    quote_symbol: nil,
    quote_address: nil,
    base_address: nil,
    market_data: nil
  )
end
