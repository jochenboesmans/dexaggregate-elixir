defmodule Market.Pair do
	@moduledoc """
		Data structure representing a pair in the market.
	"""
	@enforce_keys [:base_symbol, :quote_symbol, :quote_address, :base_address, :market_data]
	defstruct(
		base_symbol: nil,
		quote_symbol: nil,
		quote_address: nil,
		base_address: nil,
		market_data: nil
	)
end
