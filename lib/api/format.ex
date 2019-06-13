defmodule Dexaggregatex.API.Format do
  @moduledoc false

  alias Dexaggregatex.Market.Structs.{Market, RebasedMarket, LastUpdate}

  @simple_filters [:quote_symbols, :quote_addresses, :base_symbols, :base_addresses]

  def queried_market(m, args) do
    @simple_filters
    |> Enum.reduce(m, fn (sf, acc) -> filter_market_by_simple_filter(acc, args, sf) end)
    |> filter_market_by_market_ids(args)
    |> filter_market_by_exchanges(args)
    |> format_market()
  end

  def queried_rebased_market(m, args) do
    @simple_filters
    |> Enum.reduce(m, fn (sf, acc) -> filter_market_by_simple_filter(acc, args, sf) end)
    |> filter_market_by_market_ids(args)
    |> filter_market_by_exchanges(args)
    |> format_rebased_market(args)
  end

  def queried_exchanges_in_market(eim) do
    format_exchanges_in_market(eim)
  end

  def queried_last_update(%LastUpdate{timestamp: ts, utc_time: ut, exchange: ex}) do
    %{
      timestamp: ts,
      utc_time: NaiveDateTime.to_string(ut),
      exchange: Atom.to_string(ex)
    }
  end

  defp format_market(m) do
    Enum.reduce(m, [], fn ({k, p}, acc) ->
      new_p = Map.put(p, :id, k)
      new_md =
        Enum.map(p.market_data, fn {exchange, emd} ->
          Map.put(emd, :exchange, exchange)
        end)
        |> Enum.sort_by(&(&1.base_volume), &>=/2)

      [%{new_p | market_data: new_md} | acc]
    end)
  end

  defp format_rebased_market(m, %{rebase_address: ba}) do
    pairs =
      Enum.reduce(m, [], fn ({k, p}, acc) ->
        new_p = Map.put(p, :id, k)
        new_md =
          Enum.map(p.market_data, fn {exchange, emd} ->
            Map.put(emd, :exchange, exchange)
          end)
          |> Enum.sort_by(&(&1.base_volume), &>=/2)
        [%{new_p | market_data: new_md} | acc]
      end)
      |> Enum.sort_by(&combined_volume_across_exchanges/1, &>=/2)

    %RebasedMarket{base_address: ba, pairs: pairs}
  end

  defp format_exchanges_in_market(eim) do
    MapSet.to_list(eim)
  end

  defp filter_market_by_market_ids(m, args) do
    case Map.has_key?(args, :market_ids) do
      true ->
        Enum.reduce(m, %{}, fn ({k, p}, acc) ->
          case Enum.member?(args.market_ids, k) do
            true ->
              Map.put(acc, k, p)
            false ->
              acc
          end
        end)
      false ->
        m
    end
  end

  defp field_value(filter, p) do
    case filter do
      :quote_symbols -> p.quote_symbol
      :quote_addresses -> p.quote_address
      :base_symbols -> p.base_symbol
      :base_addresses -> p.base_address
    end
  end

  defp filter_market_by_simple_filter(m, args, simple_filter) do
    case Map.has_key?(args, simple_filter) do
      true ->
        Enum.reduce(m, %{}, fn ({k, p}, acc) ->
          case Enum.member?(args[simple_filter], field_value(simple_filter, p)) do
            true ->
              Map.put(acc, k, p)
            false ->
              acc
          end
        end)
      false ->
        m
      end
  end

  defp filter_market_by_exchanges(m, args) do
    case Map.has_key?(args, :exchanges) do
      true ->
        Enum.reduce(m, %{}, fn ({k, %{market_data: md} = p}, acc1) ->
          filtered_pmd = Enum.reduce(md, %{}, fn ({e, emd}, acc2) ->
            case Enum.member?(args.exchanges, Atom.to_string(e)) do
              true ->
                Map.put(acc2, e, emd)
              false ->
                acc2
            end
          end)

          case Enum.count(filtered_pmd) do
            0 ->
              acc1
            _ ->
              Map.put(acc1, k, %{p | market_data: filtered_pmd})
          end
        end)
      false ->
        m
    end
  end

  defp combined_volume_across_exchanges(%{market_data: md}) do
    Enum.reduce(md, 0, fn (%{base_volume: bv}, acc) -> acc + bv end)
  end

end
