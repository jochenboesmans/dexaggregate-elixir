defmodule Dexaggregatex.API.GraphQL.Schema.Types do
	@moduledoc """
	API-specific GraphQL types.
	"""
	use Absinthe.Schema.Notation

	@desc "A market in which all prices and volumes are based in each pair's respective base token."
	object :market do
		field :pairs, list_of(:pair), description: "A list of pairs in the market."
	end

	@desc "A market in which all prices and volumes are based in the same token."
	object :rebased_market do
		field :base_address, :string, description: "The address of the token in which all market data is based. For example: \"0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359\" would indicate that all prices and volumes are denominated in DAI."
		field :pairs, list_of(:pair), description: "A list of pairs in the market."
	end

	@desc "A pair in the market."
	object :pair do
		field :id, non_null(:id), description: "This pair's internal ID."
		field :base_symbol, :string, description: "The symbol of the base token."
		field :base_address, :string, description: "The symbol of the quote token."
		field :quote_symbol, :string, description: "The address of the base token."
		field :quote_address, :string, description: "The address of the quote token."
		field :market_data, list_of(:exchange_market_data), description: "This pair's market data."
	end

	@desc "A pair's market data on a specific exchange."
	object :exchange_market_data do
		field :exchange, :string, description: "The exchange to which this market data belongs."
		field :last_price, :float, description: "The last price for the quote token on this exchange."
		field :current_bid, :float, description: "The highest current bid price for the quote token on this exchange."
		field :current_ask, :float, description: "The lowest current ask price for the quote token on this exchange."
		field :base_volume, :float, description: "This pair's volume on this exchange."
		field :timestamp, :integer, description: "UNIX timestamp (ms) at which this data was added to the market."
	end

	@desc "Data about the last update to the market."
	object :last_update do
		field :utc_time, :string, description: "The UTC time of the last update."
		field :pair, :pair, description: "The pair that was last updated."
		field :timestamp, :integer, description: "The UNIX timestamp of the last update."
	end
end
