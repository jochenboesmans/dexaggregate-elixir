defmodule Market.Market do
  @moduledoc """
  	Data structure representing a market, for which all data is based in a specific base address.
  """
  @enforce_keys [:pairs, :base_address]
  defstruct(
    pairs: nil,
    base_address: nil
  )
end
