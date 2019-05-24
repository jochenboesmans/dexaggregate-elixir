defmodule Graphql.Schema.ContentTypes do
	@moduledoc false
	use Absinthe.Schema.Notation

	@desc "A market in which all prices and volumes are denominated in the same base token."
	object :rebased_market do
		field :base_address, :string
		field :pairs, list_of(:pair)
	end

	@desc "A pair in the market."
	object :pair do
		field :base_symbol, :string
		field :base_address, :string
		field :quote_symbol, :string
		field :quote_address, :string
		field :market_data, list_of(:exchange_market_data)
	end

	@desc "A pair's market data on a specific exchange."
	object :exchange_market_data do
		field :exchange, :string
		field :last_price, :float
		field :current_bid, :float
		field :current_ask, :float
		field :base_volume, :float
	end

	@desc "Data about the last update to the market."
	object :last_update do
		field :timestamp, :integer
		field :exchange, :string
	end
end
