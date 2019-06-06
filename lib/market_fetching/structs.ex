defmodule Dexaggregatex.MarketFetching.Structs do
	@moduledoc """
		Data structures for newly fetched market data.
	"""

	defmodule ExchangeMarket do
		@moduledoc """
			Data structure for newly fetched markets specific to an exchange.
		"""
		@enforce_keys [:exchange, :market]
		defstruct(
			exchange: nil,
			market: nil
		)
	end

	defmodule Pair do
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

	defmodule PairMarketData do
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

end
