defmodule Dexaggregatex.API.GraphQL.Resolvers.Content do
	@moduledoc """
	Functions for resolving queried data.
	"""

	alias Dexaggregatex.Market.Rebasing
	alias Dexaggregatex.Market.Client, as: MarketClient
	alias Dexaggregatex.Market.Structs.{RebasedMarket, Market, LastUpdate}

	import Dexaggregatex.API.Format

	def get_market(_parent, args, _resolution) do
		m = MarketClient.market(args)
		{:ok, format_market(m)}
	end

	def get_rebased_market(_parent, %{rebase_address: ra} = args, _resolution) do
		rm = MarketClient.rebased_market(ra, args)
		{:ok, format_rebased_market(rm)}
	end

	def get_exchanges(_parent, _args, _resolution) do
		e = MarketClient.exchanges_in_market()
		{:ok, format_exchanges_in_market(e)}
	end

	def get_last_update(_parent, _args, _resolution) do
		lu = MarketClient.last_update()
		{:ok, format_last_update(lu)}
	end

end
