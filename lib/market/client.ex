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
	@spec market(map) :: Market.t
	def market(filters \\ %{}) do
		GenServer.call(Server, :get_market)
		|> apply_filters(filters)
	end

	@doc """
	Returns a collection of exchanges currently included in the market.
	"""
	@spec exchanges_in_market() :: MapSet.t(atom)
	def exchanges_in_market() do
		%Market{pairs: pairs} = GenServer.call(Server, :get_market)
		Enum.reduce(pairs, MapSet.new(), fn ({_k, p}, acc1) ->
			Enum.reduce(p.market_data, acc1, fn {exchange, _emd}, acc2->
				MapSet.put(acc2, exchange)
			end)
		end)
	end

	@doc """
	Returns the current market with all market data rebased in the token with the specified address.
	"""
	@spec rebased_market(String.t, map) :: RebasedMarket.t
	def rebased_market(ra, filters \\ %{}) do
		GenServer.call(Server, :get_market)
		|> Rebasing.rebase_market(ra, 3)
		|> apply_filters(filters)
	end


	@doc """
	Get data about the last update to the market.
	"""
	@spec last_update() :: LastUpdate.t
	def last_update(), do: GenServer.call(Server, :get_last_update)

	@doc """
	Updates the market with the given pair or exchange market.
	"""
	@spec update(Pair.t | ExchangeMarket.t) :: :ok
	def update(p_or_em) do
		GenServer.cast(Server, {:update, p_or_em})
	end

	@simple_filters [:quote_symbols, :quote_addresses, :base_symbols, :base_addresses]

	defp apply_filters(m, filters) do
		Enum.reduce(filters, m, fn (f, acc) -> apply_filter(f, acc) end)
	end

	defp apply_filter({filter_name, values}, m) do
		filtered_pairs =
			case filter_name do
				:rebase_address -> m.pairs
				:exchanges -> filter_pairs_by_exchanges(m, values)
				_ ->
					Enum.filter(m.pairs, fn ({k, p}) ->
						case Enum.member?(@simple_filters, filter_name) do
							true ->
								Enum.member?(values, simple_filter_field_value(filter_name, p))
							false ->
								case filter_name do
									:market_ids ->
										Enum.member?(values, k)
								end
						end
					end)
			end

		%{m | pairs: filtered_pairs}
	end

	defp simple_filter_field_value(filter_name, p) do
		case filter_name do
			:quote_symbols -> p.quote_symbol
			:quote_addresses -> p.quote_address
			:base_symbols -> p.base_symbol
			:base_addresses -> p.base_address
		end
	end

	defp filter_pairs_by_exchanges(m, exchanges) do
		Enum.reduce(m.pairs, %{}, fn ({k, %{market_data: md} = p}, acc1) ->
			filtered_pmd = Enum.reduce(md, %{}, fn ({e, emd}, acc2) ->
				case Enum.member?(exchanges, Atom.to_string(e)) do
					true -> Map.put(acc2, e, emd)
					false -> acc2
				end
			end)

			case Enum.count(filtered_pmd) do
				0 -> acc1
				_ -> Map.put(acc1, k, %{p | market_data: filtered_pmd})
			end
		end)
	end

end
