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

	def get_rebased_market(_parent, %{rebase_address: ra} = args, _resolution) do
		case Market.get({:rebased_market, ra}) do
			nil ->
				{:error, "Failed to rebase market to specified token address."}
			%Market.Market{base_address: ba, pairs: m} ->
				r =
					filter_market_by_exchanges(m, args)
          |> filter_market_by_market_ids(args)
          |> format_rebased_market()
				{:ok, %Market.Market{base_address: ba, pairs: r}}
		end
	end

	def get_exchanges(_parent, _args, _resolution) do
		case Market.get(:exchanges) do
			nil ->
				{:error, "Failed to retrieve exchanges in market."}
			e ->
				{:ok, format_exchanges_in_market(e)}
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
