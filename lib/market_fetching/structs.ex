defmodule Dexaggregatex.MarketFetching.Structs do
	@moduledoc """
	Data structures for newly fetched market data.
	"""

	defmodule PairMarketData do
		@moduledoc """
		Data structure for newly fetched market data specific to a pair on an exchange.
		All prices and volumes are denominated in the base token and are exchange-specific.
		"""
		@enforce_keys [:exchange, :last_price, :current_bid, :current_ask, :base_volume]
		defstruct [:exchange, :last_price, :current_bid, :current_ask, :base_volume]

		@typedoc """
		* exchange: atom representing exchange (i.e. :uniswap).
		* last_price: number representing the last price for the quote token.
		* current_bid: number representing the highest current bid price for the quote token.
		* current_ask: number representing the lowest current ask price for the quote token.
		* base_volume: number representing a pair's volume.
		"""
		@type t :: %__MODULE__{exchange: atom, last_price: number,
								 current_bid: number, current_ask: number, base_volume: number}
	end

	defmodule Pair do
		alias Dexaggregatex.MarketFetching.Structs.PairMarketData
		@moduledoc """
		Data structure for newly fetched data specific to a pair on an exchange.
		"""
		@enforce_keys [:base_symbol, :quote_symbol, :base_address, :quote_address, :market_data]
		defstruct [:base_symbol, :quote_symbol, :base_address, :quote_address, :market_data]

		@typedoc """
		* base_symbol: string representing the symbol of the base token.
		* quote_symbol: string representing the symbol of the quote token.
		* base_address: string representing the address of the base token.
		* quote_address: string representing the address of the quote token.
		* market_data: struct representing this pair's market data.
		"""
		@type t :: %__MODULE__{base_symbol: String.t, quote_symbol: String.t, base_address: String.t,
								 quote_address: String.t, market_data: PairMarketData.t}
	end

	defmodule ExchangeMarket do
		alias Dexaggregatex.MarketFetching.Structs.Pair
		@moduledoc """
		Data structure for newly fetched markets specific to an exchange.
		"""
		@enforce_keys [:exchange, :pairs]
		defstruct [:exchange, :pairs]

		@typedoc """
		* exchange: atom representing exchange (i.e. :uniswap).
		* pairs: list of pairs on the exchange.
		"""
		@type t :: %__MODULE__{exchange: atom, pairs: [Pair.t]}
	end

end
