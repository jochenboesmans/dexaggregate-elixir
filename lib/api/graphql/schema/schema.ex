defmodule Dexaggregatex.API.GraphQL.Schema do
	@moduledoc false
	use Absinthe.Schema

	import_types Dexaggregatex.API.GraphQL.Schema.Types
	alias Dexaggregatex.API.GraphQL.Resolvers.Content

	query do
		description "All available queries."
		field :market, :market do
			description "Get the market, with all market data based in each pair's respective base token."
			arg :exchanges, list_of(non_null(:string)), description: "A list of exchanges by which to filter the market. For example: [\"kyber\",\"uniswap\"] will only return market data from Kyber and Uniswap exchanges."
			arg :pair_ids, list_of(non_null(:id)), description: "A list of pair ids by which to filter the market. For example: [\"HTGttJeVuGjnHq+nlifj9CAlSXnr49PRE3Y+f8lP4vZKvLCcxeWjUXJ5oBEwax+BczfAC7st5HSuOSnOZjKF8A==\"] will only return market data from the ETH/DAI pair."
			arg :base_symbols, list_of(non_null(:string)), description: "A list of base symbols by which to filter the market. For example: [\"ETH\"] will return all market data for pairs based in ETH."
			arg :base_addresses, list_of(non_null(:string)), description: "A list of base addresses by which to filter the market. For example: [\"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\"] will return all market data for pairs based in ETH. Using addresses instead of symbols assures token uniqueness (there might be multiple tokens with the same symbol)."
			arg :quote_symbols, list_of(non_null(:string)), description: "A list of quote symbols by which to filter the market. For example: [\"DAI\"] will return all market data for pairs that quote DAI."
			arg :quote_addresses, list_of(non_null(:string)), description: "A list of quote addresses by which to filter the market. For example: [\"0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359\"] will return all market data for pairs that quote DAI. Using addresses instead of symbols assures token uniqueness (there might be multiple tokens with the same symbol)."
			resolve &Content.get_market/2
		end

		field :rebased_market, :rebased_market do
			description "Get the market, with all market data rebased in the token with the specified rebase_address."
			arg :rebase_address, non_null(:string), description: "The address of the token in which to rebase the market. For example: \"0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359\" will return a DAI-rebased market."
			arg :exchanges, list_of(non_null(:string)), description: "A list of exchanges by which to filter the market. For example: [\"kyber\",\"uniswap\"] will only return market data from Kyber and Uniswap exchanges."
			arg :pair_ids, list_of(non_null(:id)), description: "A list of pair ids by which to filter the market. For example: [\"HTGttJeVuGjnHq+nlifj9CAlSXnr49PRE3Y+f8lP4vZKvLCcxeWjUXJ5oBEwax+BczfAC7st5HSuOSnOZjKF8A==\"] will only return market data from the ETH/DAI pair."
			arg :base_symbols, list_of(non_null(:string)), description: "A list of base symbols by which to filter the market. For example: [\"ETH\"] will return all market data for pairs based in ETH."
			arg :base_addresses, list_of(non_null(:string)), description: "A list of base addresses by which to filter the market. For example: [\"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\"] will return all market data for pairs based in ETH. Using addresses instead of symbols assures token uniqueness (there might be multiple tokens with the same symbol)."
			arg :quote_symbols, list_of(non_null(:string)), description: "A list of quote symbols by which to filter the market. For example: [\"DAI\"] will return all market data for pairs that quote DAI."
			arg :quote_addresses, list_of(non_null(:string)), description: "A list of quote addresses by which to filter the market. For example: [\"0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359\"] will return all market data for pairs that quote DAI. Using addresses instead of symbols assures token uniqueness (there might be multiple tokens with the same symbol)."
			resolve &Content.get_rebased_market/2
		end

		field :exchanges, list_of(:string) do
			description "Get all exchanges currently in the market."
			resolve &Content.get_exchanges/2
		end

		field :last_update, :last_update do
			description "Get data about the last update to the market."
			resolve &Content.get_last_update/2
		end
	end

	subscription do
		description "All available subscriptions."
		field :market, :market do
			description "Subscribe to the market, with all market data based in each pair's respective base token."
			arg :exchanges, list_of(non_null(:string)), description: "A list of exchanges by which to filter the market. For example: [\"kyber\",\"uniswap\"] will only return market data from Kyber and Uniswap exchanges."
			arg :pair_ids, list_of(non_null(:id)), description: "A list of pair ids by which to filter the market. For example: [\"HTGttJeVuGjnHq+nlifj9CAlSXnr49PRE3Y+f8lP4vZKvLCcxeWjUXJ5oBEwax+BczfAC7st5HSuOSnOZjKF8A==\"] will only return market data from the ETH/DAI pair."
			arg :base_symbols, list_of(non_null(:string)), description: "A list of base symbols by which to filter the market. For example: [\"ETH\"] will return all market data for pairs based in ETH."
			arg :base_addresses, list_of(non_null(:string)), description: "A list of base addresses by which to filter the market. For example: [\"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\"] will return all market data for pairs based in ETH. Using addresses instead of symbols assures token uniqueness (there might be multiple tokens with the same symbol)."
			arg :quote_symbols, list_of(non_null(:string)), description: "A list of quote symbols by which to filter the market. For example: [\"DAI\"] will return all market data for pairs that quote DAI."
			arg :quote_addresses, list_of(non_null(:string)), description: "A list of quote addresses by which to filter the market. For example: [\"0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359\"] will return all market data for pairs that quote DAI. Using addresses instead of symbols assures token uniqueness (there might be multiple tokens with the same symbol)."

			config fn (_args, _info) -> {:ok, topic: "*"} end
			resolve &Content.get_market/2
		end

		field :rebased_market, :rebased_market do
			description "Subscribe to the market, with all market data rebased in the token with the specified rebase_address."
			arg :rebase_address, non_null(:string), description: "The address of the token in which to rebase the market. For example: \"0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359\" will return a DAI-rebased market."
			arg :exchanges, list_of(non_null(:string)), description: "A list of exchanges by which to filter the market. For example: [\"kyber\",\"uniswap\"] will only return market data from Kyber and Uniswap exchanges."
			arg :pair_ids, list_of(non_null(:id)), description: "A list of pair ids by which to filter the market. For example: [\"HTGttJeVuGjnHq+nlifj9CAlSXnr49PRE3Y+f8lP4vZKvLCcxeWjUXJ5oBEwax+BczfAC7st5HSuOSnOZjKF8A==\"] will only return market data from the ETH/DAI pair."
			arg :base_symbols, list_of(non_null(:string)), description: "A list of base symbols by which to filter the market. For example: [\"ETH\"] will return all market data for pairs based in ETH."
			arg :base_addresses, list_of(non_null(:string)), description: "A list of base addresses by which to filter the market. For example: [\"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\"] will return all market data for pairs based in ETH. Using addresses instead of symbols assures token uniqueness (there might be multiple tokens with the same symbol)."
			arg :quote_symbols, list_of(non_null(:string)), description: "A list of quote symbols by which to filter the market. For example: [\"DAI\"] will return all market data for pairs that quote DAI."
			arg :quote_addresses, list_of(non_null(:string)), description: "A list of quote addresses by which to filter the market. For example: [\"0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359\"] will return all market data for pairs that quote DAI. Using addresses instead of symbols assures token uniqueness (there might be multiple tokens with the same symbol)."

			config fn (_args, _info) -> {:ok, topic: "*"} end
			resolve &Content.get_rebased_market/2
		end

		field :exchanges, list_of(:string) do
			description "Subscribe to a list of all exchanges currently in the market."
			config fn (_args, _info) -> {:ok, topic: "*"} end
			resolve &Content.get_exchanges/2
		end

		field :last_update, :last_update do
			description "Subscribe to data about the last update to the market."
			config fn (_args, _info) -> {:ok, topic: "*"} end
			resolve &Content.get_last_update/2
		end
	end
end
