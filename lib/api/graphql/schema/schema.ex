defmodule Dexaggregatex.API.GraphQL.Schema do
	@moduledoc false
	use Absinthe.Schema

	import_types Dexaggregatex.API.GraphQL.Schema.Types
	alias Dexaggregatex.API.GraphQL.Resolvers.Content

	query do
		@desc "Get the market, not rebased."
		field :market, list_of(:pair) do
			arg :exchanges, list_of(non_null(:string))
			arg :market_ids, list_of(non_null(:id))
			arg :base_symbols, list_of(non_null(:string))
			arg :base_addresses, list_of(non_null(:string))
			arg :quote_symbols, list_of(non_null(:string))
			arg :quote_addresses, list_of(non_null(:string))
			resolve &Content.get_market/3
		end

		@desc "Get the market rebased in the specified token."
		field :rebased_market, :rebased_market do
			arg :rebase_address, non_null(:string)
			arg :exchanges, list_of(non_null(:string))
			arg :market_ids, list_of(non_null(:id))
			arg :base_symbols, list_of(non_null(:string))
			arg :base_addresses, list_of(non_null(:string))
			arg :quote_symbols, list_of(non_null(:string))
			arg :quote_addresses, list_of(non_null(:string))
			resolve &Content.get_rebased_market/3
		end

		@desc "Get all exchanges currently in the market."
		field :exchanges, list_of(:string) do
			resolve &Content.get_exchanges/3
		end

		@desc "Get data about the last update to the market."
		field :last_update, :last_update do
			resolve &Content.get_last_update/3
		end
	end

	subscription do
		@desc "Subscribe to the market, not rebased."
		field :market, list_of(:pair) do
			arg :exchanges, list_of(non_null(:string))
			arg :market_ids, list_of(non_null(:id))
			arg :base_symbols, list_of(non_null(:string))
			arg :base_addresses, list_of(non_null(:string))
			arg :quote_symbols, list_of(non_null(:string))
			arg :quote_addresses, list_of(non_null(:string))

			config fn (_args, _info) -> {:ok, topic: "*"} end

			resolve &Content.get_market/3
		end

		@desc "Subscribe to the market, rebased in the token with the specified rebase_address."
		field :rebased_market, :rebased_market do
			arg :rebase_address, non_null(:string)
			arg :exchanges, list_of(non_null(:string))
			arg :market_ids, list_of(non_null(:id))
			arg :base_symbols, list_of(non_null(:string))
			arg :base_addresses, list_of(non_null(:string))
			arg :quote_symbols, list_of(non_null(:string))
			arg :quote_addresses, list_of(non_null(:string))

			config fn (_args, _info) -> {:ok, topic: "*"} end

			resolve &Content.get_rebased_market/3
		end

		@desc "Subscribe to a list of all exchanges currently in the market."
		field :exchanges, list_of(:string) do
			config fn (_args, _info) -> {:ok, topic: "*"} end
			resolve &Content.get_exchanges/3
		end

		@desc "Subscribe to data about the last update to the market."
		field :last_update, :last_update do
			config fn (_args, _info) -> {:ok, topic: "*"} end
			resolve &Content.get_last_update/3
		end
	end
end
