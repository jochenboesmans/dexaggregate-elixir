defmodule Dexaggregatex.Market.Structs do
  @moduledoc """
  Data structures representing parts of the internal market model.
  """

  defmodule ExchangeMarketData do
    @moduledoc """
    Data structure containing exchange-specific market data for a pair.
    """
    @enforce_keys [:last_price, :current_bid, :current_ask, :base_volume, :timestamp]
    defstruct [:last_price, :current_bid, :current_ask, :base_volume, :timestamp]

    @typedoc """
    * last_price: number representing the last price for the quote token.
    * current_bid: number representing the highest current bid price for the quote token.
    * current_ask: number representing the lowest current ask price for the quote token.
    * base_volume: number representing a pair's volume.
    * timestamp: integer representing the UNIX timestamp at which this EMD was added to the market.
    """
    @type t :: %__MODULE__{
            last_price: number,
            current_bid: number,
            current_ask: number,
            base_volume: number,
            timestamp: integer
          }
  end

  defmodule Pair do
    alias Dexaggregatex.Market.Structs.ExchangeMarketData

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
    @type market_data :: %{optional(String.t()) => ExchangeMarketData.t()}
    @type t :: %__MODULE__{
            base_symbol: String.t(),
            quote_symbol: String.t(),
            base_address: String.t(),
            quote_address: String.t(),
            market_data: market_data
          }
  end

  defmodule RebasedMarket do
    alias Dexaggregatex.Market.Structs.Pair

    @moduledoc """
    Data structure representing a market, for which all market data is based in a specific base token.
    """
    @enforce_keys [:base_address, :pairs]
    defstruct [:base_address, :pairs]

    @typedoc """
    * base_address: string representing the address of the token in which this market's data is based.
    * pairs: map of pair_id => pair in the market.
    """
    @type pairs :: %{optional(String.t()) => Pair.t()}
    @type t :: %__MODULE__{base_address: String.t(), pairs: pairs}
  end

  defmodule Market do
    @moduledoc """
    Data structure representing a raw market, for which all market data is based in each pair's respective base token.
    """
    @enforce_keys [:pairs]
    defstruct [:pairs]

    @typedoc """
    * pairs: map of pair_id => pair in the market.
    """
    @type pairs :: %{optional(String.t()) => Pair.t()}
    @type t :: %__MODULE__{pairs: pairs}
  end

  defmodule LastUpdate do
    alias Dexaggregatex.Market.Structs.Pair

    @moduledoc """
    Data structure representing the last update of the market.
    """
    @enforce_keys [:utc_time, :pair, :timestamp]
    defstruct [:utc_time, :pair, :timestamp]

    @typedoc """
    * utc_time: struct representing the utc time of the last update.
    * pair: struct representing the pair that was last updated.
    * timestamp: integer representing the timestamp of the last update.
    """
    @type t :: %__MODULE__{utc_time: NaiveDateTime.t(), pair: Pair.t(), timestamp: integer}
  end
end
