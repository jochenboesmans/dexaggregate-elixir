defmodule Dexaggregatex.API.GraphQL.Resolvers.Content do
	@moduledoc false

	alias Dexaggregatex.Market.Rebasing
	alias Dexaggregatex.Market.Client, as: MarketClient
	alias Dexaggregatex.Market.Structs.{RebasedMarket, Market, LastUpdate}

	import Dexaggregatex.API.Format

	def get_market(_parent, args, _resolution) do
		%Market{pairs: m} = MarketClient.get(:market)
		{:ok, queried_market(m, args)}
	end

	def get_rebased_market(_parent, %{rebase_address: ra} = args, _resolution) do
		m = %Market{} = MarketClient.get(:market)
		%RebasedMarket{pairs: rm} = Rebasing.rebase_market(ra, m, 3)
		{:ok, queried_rebased_market(rm, args)}
	end

	def get_exchanges(_parent, _args, _resolution) do
		e = MarketClient.get(:exchanges)
		{:ok, queried_exchanges_in_market(e)}
	end

	def get_last_update(_parent, _args, _resolution) do
		lu = %LastUpdate{} = MarketClient.get(:last_update)
		{:ok, queried_last_update(lu)}
	end

end
