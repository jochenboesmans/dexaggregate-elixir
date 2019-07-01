defmodule Dexaggregatex.Market.Client do
  @moduledoc """
  Endpoint for interacting with a market server.
  """
  alias Dexaggregatex.Market.Server
  alias Dexaggregatex.Market.Structs.{Market, RebasedMarket, LastUpdate}
  alias Dexaggregatex.Market.Structs.Pair, as: MarketPair
  alias Dexaggregatex.MarketFetching.Structs.{ExchangeMarket}
  alias Dexaggregatex.MarketFetching.Structs.Pair, as: MarketFetchingPair
  alias Dexaggregatex.Market.Rebasing
  alias Dexaggregatex.Market.InactivitySweeper.Result, as: SweepingResult
  alias Dexaggregatex.Market.CheapestPaths
  import Dexaggregatex.Market.Util
  import Dexaggregatex.Util

  @doc """
  Get the latest unrebased market data.
  """
  @spec market(map) :: Market.t()
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

    Enum.reduce(pairs, MapSet.new(), fn {_k, p}, acc1 ->
      Enum.reduce(p.market_data, acc1, fn {exchange, _emd}, acc2 ->
        MapSet.put(acc2, exchange)
      end)
    end)
  end

  @doc """
  Returns the current market with all market data rebased in the token with the specified address.
  """
  @spec rebased_market(%{required(:rebase_address) => String.t(), optional(any) => any}) ::
          RebasedMarket.t()
  def rebased_market(%{rebase_address: ra} = args) do
    filters = Map.delete(args, :rebase_address)

    GenServer.call(Server, :get_market)
    |> Rebasing.rebase_market(ra, 3)
    |> apply_filters(filters)
  end

  @doc """
  Returns volume-weighted spread averages for each token of a rebased market.
  """
  @spec cheapest_paths(%{
          from_address: String.t(),
          to_address: String.t(),
          rebase_address: String.t(),
          amount: number
        }) ::
          [%{rate: number, path: [Pair.t()]}]
  def cheapest_paths(%{from_address: fa, to_address: ta, rebase_address: ra, amount: a}) do
    GenServer.call(Server, :get_market)
    |> Rebasing.rebase_market(ra, 3)
    |> CheapestPaths.cheapest_paths(fa, ta, a)
  end

  @doc """
  Returns the average of all volume-weighted spread averages for each token in a rebased market, functioning as sort of
  a price oracle.
  Regular volume-weighted spread averages are used for quote tokens and inverted volume-weighted spread averages are
  used for base tokens.

  CURRENTLY NOT IN USE; REPLACE WITH CHEAPEST PATHS MODULE FUNCTIONALITY.
  """
  @spec aggregate_vwsa(RebasedMarket.t()) :: %{optional(String.t()) => number}
  defp aggregate_vwsa(%RebasedMarket{pairs: pairs} = _rm) do
    Enum.reduce(pairs, %{}, fn {k,
                                %MarketPair{quote_address: qa, base_address: ba, market_data: md} =
                                  p},
                               acc ->
      %{wsa: wsa, tv: tv} =
        Enum.reduce(md, %{wsa: 0, tv: 0}, fn {_k, emd}, %{wsa: wsa, tv: tv} ->
          w = (emd.current_bid + emd.current_ask) / 2 * emd.base_volume
          %{wsa: wsa + w, tv: tv + emd.base_volume}
        end)

      Map.update(acc, qa, %{sum: 0, amount: 0}, fn prev_value ->
        case prev_value do
          %{sum: prev_sum, amount: prev_amount} ->
            %{sum: prev_sum + wsa, amount: prev_amount + tv}

          _ ->
            %{sum: wsa, amount: tv}
        end
      end)
      |> Map.update(ba, %{sum: 0, amount: 0}, fn prev_value ->
        case prev_value do
          %{sum: prev_sum, amount: prev_amount} ->
            %{sum: prev_sum + safe_div(1, wsa), amount: prev_amount + tv}

          _ ->
            %{sum: safe_div(1, wsa), amount: tv}
        end
      end)
    end)
    |> Enum.reduce(%{}, fn {k, %{sum: total_sum, amount: amount_of_sums}}, acc ->
      Map.put(acc, k, safe_div(total_sum, amount_of_sums))
    end)
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      case v != 0,
        do:
          (
            true -> Map.put(acc, k, v)
            false -> acc
          )
    end)
  end

  @doc """
  Get data about the last update to the market.
  """
  @spec last_update() :: LastUpdate.t()
  def last_update(), do: GenServer.call(Server, :get_last_update)

  @doc """
  Updates the market with the given pair or exchange market.
  """
  @spec update(MarketFetchingPair.t() | ExchangeMarket.t()) :: :ok
  def update(p_or_em), do: GenServer.cast(Server, {:update, p_or_em})

  @doc """
  Feed a SweepingResult to the market.
  """
  @spec eat_swept_market(SweepingResult.t()) :: :ok
  def eat_swept_market(%SweepingResult{} = sr) do
    GenServer.cast(Server, {:eat_swept_market, sr})
  end

  @simple_filters [:quote_symbols, :quote_addresses, :base_symbols, :base_addresses]
  @type simple_filter :: :quote_symbols | :quote_addresses | :base_symbols | :base_addresses

  @spec apply_filters(Market.t() | RebasedMarket.t(), map) :: Market.t() | RebasedMarket.t()
  defp apply_filters(m, filters) do
    Enum.reduce(filters, m, fn f, acc -> apply_filter(f, acc) end)
  end

  @spec apply_filter({atom, [binary]}, Market.t() | RebasedMarket.t()) ::
          Market.t() | RebasedMarket.t()
  defp apply_filter({filter, values}, %{pairs: pairs} = m) do
    filtered_pairs =
      case filter do
        :rebase_address ->
          pairs

        :exchanges ->
          filter_pairs_by_exchanges(m, values)

        _ ->
          Enum.reduce(pairs, %{}, fn {k, p}, acc ->
            case Enum.member?(@simple_filters, filter) do
              true ->
                case Enum.member?(values, simple_filter_field_value(filter, p)) do
                  true -> Map.put(acc, k, p)
                  false -> acc
                end

              false ->
                case filter do
                  :market_ids ->
                    case Enum.member?(values, k) do
                      true -> Map.put(acc, k, p)
                      false -> acc
                    end
                end
            end
          end)
      end

    %{m | pairs: filtered_pairs}
  end

  @spec filter_pairs_by_exchanges(Market.t() | RebasedMarket.t(), [String.t()]) ::
          Market.t() | RebasedMarket.t()
  defp filter_pairs_by_exchanges(m, exchanges) do
    Enum.reduce(m.pairs, %{}, fn {k, %MarketPair{market_data: md} = p}, acc1 ->
      filtered_pmd =
        Enum.reduce(md, %{}, fn {e, emd}, acc2 ->
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

  @spec simple_filter_field_value(simple_filter, MarketPair.t()) :: String.t()
  defp simple_filter_field_value(filter_name, p) do
    case filter_name do
      :quote_symbols -> p.quote_symbol
      :quote_addresses -> p.quote_address
      :base_symbols -> p.base_symbol
      :base_addresses -> p.base_address
    end
  end
end
