defmodule Dexaggregatex.API.GraphQL.Resolvers.Content do
	@moduledoc """
	Absinthe resolvers.
	"""
	alias Dexaggregatex.Market.Client, as: MarketClient
	alias Dexaggregatex.Market.Structs.{RebasedMarket, Market, LastUpdate}
	import Dexaggregatex.API.Format

	@spec get_market(Absinthe.Resolution.arguments, Absinthe.Resolution.t) :: {:ok, map}
	def get_market(args, _resolution) do
		m = %Market{} = MarketClient.market(args)
		{:ok, format_market(m)}
	end

	@spec get_rebased_market(Absinthe.Resolution.arguments, Absinthe.Resolution.t) :: {:ok, map}
	def get_rebased_market(args, _resolution) do
		rm = %RebasedMarket{} = MarketClient.rebased_market(args)
		{:ok, format_rebased_market(rm)}
	end

	@spec get_exchanges(Absinthe.Resolution.arguments, Absinthe.Resolution.t) :: {:ok, [String.t]}
	def get_exchanges(_args, _resolution) do
		e = MarketClient.exchanges_in_market()
		{:ok, format_exchanges_in_market(e)}
	end

	@spec get_last_update(Absinthe.Resolution.arguments, Absinthe.Resolution.t) :: {:ok, map}
	def get_last_update(_args, _resolution) do
		lu = %LastUpdate{} = MarketClient.last_update()
		{:ok, format_last_update(lu)}
	end
end
