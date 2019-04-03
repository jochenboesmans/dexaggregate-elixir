defmodule MarketFetchers.Structs.ExchangeMarket do
  @moduledoc false

  @enforce_keys [
    :exchange,
    :market
  ]

  defstruct(
    exchange: nil,
    market: nil
  )
end
