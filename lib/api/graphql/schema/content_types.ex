defmodule Graphql.Schema.ContentTypes do
	@moduledoc false

	use Absinthe.Schema.Notation

	object :pair do
		field :base_symbol, :string
		field :base_address, :string
		field :quote_symbol, :string
		field :quote_address, :string
		field :market_data, list_of(:exchange_market_data)
	end

	object :exchange_market_data do
		field :exchange, :string
		field :last_price, :float
		field :current_bid, :float
		field :current_ask, :float
		field :base_volume, :float
		field :quote_volume, :float
	end

end
