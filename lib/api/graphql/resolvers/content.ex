defmodule Graphql.Resolvers.Content do
	@moduledoc false

	def get_market(_parent, _args, _resolution) do
		{:ok, Market.get(:market)}
	end

	def get_rebased_market(_parent, args, _resolution) do
		{:ok, Market.get({:rebased_market, args})}
	end

	def get_exchanges(_parent, _args, _resolution) do
		{:ok, Market.get(:exchanges)}
	end

	def get_last_update(_parent, _args, _resolution) do
		{:ok, Market.get(:last_update)}
	end
end
