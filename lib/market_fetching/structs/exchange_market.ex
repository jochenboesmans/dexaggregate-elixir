defmodule MarketFetching.ExchangeMarket do
	@moduledoc """
		Data structure for newly fetched markets specific to an exchange.
	"""

	@enforce_keys [:exchange, :market]

	defstruct(
		exchange: nil,
		market: nil,
	)
end
