defmodule Dexaggregatex.API.GraphQL.Resolvers.Content do
	@moduledoc false

	alias Dexaggregatex.Market.Client, as: MarketClient
	alias Dexaggregatex.Market.Structs.{RebasedMarket, Market, LastUpdate}

	import Dexaggregatex.API.Format

	def get_market(_parent, args, _resolution) do
		%Market{pairs: m} = MarketClient.get(:market)
		{:ok, queryable_market(m, args)}
	end

	def get_rebased_market(_parent, %{rebase_address: ra} = args, _resolution) do
		%RebasedMarket{pairs: m} = MarketClient.get({:rebased_market, ra})
		{:ok, queryable_rebased_market(m, args)}
	end

	def get_exchanges(_parent, _args, _resolution) do
		e = MarketClient.get(:exchanges)
		{:ok, queryable_exchanges_in_market(e)}
	end

	def get_last_update(_parent, _args, _resolution) do
		lu = %LastUpdate{} = MarketClient.get(:last_update)
		{:ok, queryable_last_update(lu)}
	end

end
