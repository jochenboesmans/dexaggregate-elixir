defmodule MarketTypes do
  @moduledoc false

  object :market_queries do
    @desc "Get the whole market"
    field :market, list_of(:market) do
      resolve()
    end
  end
end
