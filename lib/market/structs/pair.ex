defmodule Market.Pair do
	@moduledoc """
		Data structure representing a pair in the market.
	"""
	defstruct(
		base_symbol: nil,
		quote_symbol: nil,
		quote_address: nil,
		base_address: nil,
		market_data: nil
	)
end
