defmodule Dexaggregatex.Market.Structs do
	@moduledoc """
	Data structures representing parts of the internal market model.
	"""

	defmodule Market do
		@moduledoc """
		Data structure representing a market, for which all market data is based in a specific base address.
		"""
		@enforce_keys [:base_address, :pairs]
		defstruct [:base_address, :pairs]

		@typedoc """
		* base_address: string representing the address of the token in which this market's data is based.
		* pairs: list of pairs in the market.
		"""
		@type t :: %__MODULE__{base_address: String.t(), pairs: [Pair]}
	end

	defmodule Pair do
		@moduledoc """
		Data structure representing a pair in the market.
		"""
		@enforce_keys [:base_symbol, :quote_symbol, :quote_address, :base_address, :market_data]
		defstruct [:base_symbol, :quote_symbol, :quote_address, :base_address, :market_data]

		@typedoc """
		* base_symbol: string representing the symbol of the base token.
		* quote_symbol: string representing the symbol of the quote token.
		* base_address: string representing the address of the base token.
		* quote_symbol: string representing the address of the quote token.
		* market_data: struct representing this pair's market data.
		"""
		@type t :: %__MODULE__{base_symbol: String.t(), quote_symbol: String.t(), base_address: String.t(),
							 quote_address: String.t(), market_data: [ExchangeMarketData.t()]}
	end

	defmodule ExchangeMarketData do
		@moduledoc """
		Data structure containing exchange-specific market data for a pair.
		"""
		@enforce_keys [:last_price, :current_bid, :current_ask, :base_volume]
		defstruct [:last_price, :current_bid, :current_ask, :base_volume]

		@typedoc """
		* last_price: number representing the last price for the quote token.
		* current_bid: number representing the highest current bid price for the quote token.
		* current_ask: number representing the lowest current ask price for the quote token.
		* base_volume: number representing a pair's volume.
		"""
		@type t :: %__MODULE__{last_price: number(), current_bid: number(),
								 current_ask: number(), base_volume: number()}
	end

	defmodule LastUpdate do
		@moduledoc """
		Data structure representing the last update of the market.
		"""
		@enforce_keys [:timestamp, :utc_time, :exchange]
		defstruct [:timestamp, :utc_time, :exchange]

		@typedoc """
		* timestamp: integer representing a UNIX timestamp (ms) of the last update.
		* utc_time: struct representing the utc time of the last update.
		* exchange: atom representing the exchange that caused the last update.
		"""
		@type t :: %__MODULE__{timestamp: integer(), utc_time: NaiveDateTime.t(), exchange: atom()}
	end

end
