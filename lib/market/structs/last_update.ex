defmodule Market.LastUpdate do
  @moduledoc """
  	Data structure representing the last update of the market.
  """
  @enforce_keys [:timestamp, :exchange]
  defstruct(
    timestamp: nil,
    exchange: nil
  )
end
