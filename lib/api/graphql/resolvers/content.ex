defmodule Graphql.Resolvers.Content do
	@moduledoc false

	import Graphql.Resolvers.Util

	def get_market(_parent, args, _resolution) do
		case Market.get(:market) do
			nil ->
				{:error, "Market not found."}
			m ->
				r =
					format_market(m)
					|> filter_market_by_exchanges(args)
					|> filter_market_by_market_ids(args)
				{:ok, r}
		end

	end

	def get_rebased_market(_parent, args, _resolution) do
		%{rebase_address: ra, exchange: e, market_ids: ids} = args

		case Market.get({:rebased_market, ra}) do
			nil ->
				{:error, "Failed to rebase market to specified token address."}
			rm ->
				{:ok, filter_market_by_exchanges(rm, e) |> filter_market_by_market_ids(ids)}
		end
	end

	def get_exchanges(_parent, _args, _resolution) do
		case Market.get(:exchanges) do
			nil ->
				{:error, "Failed to retrieve exchanges in market."}
			e ->
				{:ok, e}
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
