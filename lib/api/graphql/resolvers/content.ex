defmodule Dexaggregatex.API.GraphQL.Resolvers.Content do
	@moduledoc false

	alias Dexaggregatex.Market
	alias Dexaggregatex.Market.Structs

	import Dexaggregatex.API.Format

	def get_market(_parent, args, _resolution) do
		case Market.get(:market) do
			nil ->
        {:error, "Market not found."}
			m ->
        {:ok, queryable_market(m, args)}
		end
	end

	def get_rebased_market(_parent, %{rebase_address: ra} = args, _resolution) do
		case Market.get({:rebased_market, ra}) do
			nil ->
				{:error, "Failed to rebase market to specified token address."}
			%Structs.Market{pairs: m} ->
        {:ok, queryable_rebased_market(m, args)}
		end
	end

	def get_exchanges(_parent, _args, _resolution) do
		case Market.get(:exchanges) do
			nil ->
				{:error, "Failed to retrieve exchanges in market."}
			e ->
				{:ok, queryable_exchanges_in_market(e)}
		end
	end

	def get_last_update(_parent, _args, _resolution) do
		case Market.get(:last_update) do
			nil ->
				{:error, "Failed to retrieve last update to market."}
			lu ->
				{:ok, lu}
		end
	end

end
