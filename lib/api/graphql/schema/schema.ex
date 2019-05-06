defmodule Graphql.Schema do
	@moduledoc false

	use Absinthe.Schema
	import_types Graphql.Schema.ContentTypes

	alias Graphql.Resolvers.Content

	query do
		@desc "Get the whole market"
		field :market, :market do
			resolve &Content.get_market/3
		end
	end
end
