defmodule Dexaggregatex.Market.Client do
	@moduledoc """
	Endpoint for interacting with a market server.
	"""
	alias Dexaggregatex.Market.Server
	alias Dexaggregatex.Market.Structs.{Market, RebasedMarket, LastUpdate}
	alias Dexaggregatex.MarketFetching.Structs.{Pair, ExchangeMarket}
	alias Dexaggregatex.Market.Rebasing

	@doc """
	Get the latest unrebased market data.
	"""
	@spec get(:market) :: Market.t
	def get(:market), do: GenServer.call(Server, :get_market)

	@doc """
	Get the latest market data, rebased in the token with the specified rebase_address.
	"""
	@spec get({:rebased_market, String.t}) :: RebasedMarket.t
	def get({:rebased_market, rebase_address}) do
		GenServer.call(Server, {:get_rebased_market, rebase_address})
	end

	@doc """
	Get a collection of exchanges currently included in the market.
	"""
	@spec get(:exchanges) :: MapSet.t(atom)
	def get(:exchanges), do: GenServer.call(Server, :get_exchanges)

	@doc """
	Get data about the last update to the market.
	"""
	@spec get(:last_update) :: LastUpdate.t
	def get(:last_update), do: GenServer.call(Server, :get_last_update)

	@doc """
	Updates the market with the given pair.
	"""
	@spec update(Pair.t) :: :ok
	def update(%Pair{} = p) do
		Rebasing.Cache.clear()
		GenServer.cast(Server, {:update, p})
	end

	@doc """
	Updates the market with the given exchange market.
	"""
	@spec update(ExchangeMarket.t) :: :ok
	def update(%ExchangeMarket{} = em) do
		Rebasing.Cache.clear()
		GenServer.cast(Server, {:update, em})
	end
end
