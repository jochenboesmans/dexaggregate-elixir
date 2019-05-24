defmodule Graphql.Schema do
	@moduledoc false
	use Absinthe.Schema

	import_types Graphql.Schema.ContentTypes
	alias Graphql.Resolvers.Content

	query do
		@desc "Get the market, not rebased."
		field :market, list_of(:pair) do
			resolve &Content.get_market/3
		end

		@desc "Get the market rebased in the specified token."
		field :rebased_market, :rebased_market do
			arg :rebase_address, non_null(:string)
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
end
