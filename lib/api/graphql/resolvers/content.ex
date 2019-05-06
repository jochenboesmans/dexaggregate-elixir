defmodule Graphql.Resolvers.Content do
	@moduledoc false

	def get_market(_parent, _args, _resolution) do
		{:ok, Market.get(:market)}
	end

	def get_rebased_market(_parent, %{token_address: ta} = _args, _resolution) do
		{:ok, Market.get({:rebased_market, ta})}
	end

	def get_exchanges(_parent, _args, _resolution) do
		{:ok, Market.get(:exchanges)}
	end
end
