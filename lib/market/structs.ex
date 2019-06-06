defmodule Dexaggregatex.Market.Structs do
	@moduledoc """
		Data structures representing parts of the market model.
	"""

	defmodule ExchangeMarketData do
		@moduledoc """
			Data structure containing exchange-specific market data for a pair.
		"""
		@enforce_keys [:last_price, :current_bid, :current_ask, :base_volume]
		defstruct(
			last_price: nil,
			current_bid: nil,
			current_ask: nil,
			base_volume: nil
		)
	end

	defmodule LastUpdate do
		@moduledoc """
			Data structure representing the last update of the market.
		"""
		@enforce_keys [:timestamp, :exchange]
		defstruct(
			timestamp: nil,
			exchange: nil
		)
	end

	defmodule Market do
		@moduledoc """
			Data structure representing a market, for which all data is based in a specific base address.
		"""
		@enforce_keys [:pairs, :base_address]
		defstruct(
			pairs: nil,
			base_address: nil
		)
	end

	defmodule Pair do
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

end
