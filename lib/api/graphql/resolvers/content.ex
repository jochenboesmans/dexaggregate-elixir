defmodule Graphql.Resolvers.Content do
	@moduledoc false

	def get_market(_parent, _args, _resolution) do
		{:ok, Market.get(:market)}
	end
end
