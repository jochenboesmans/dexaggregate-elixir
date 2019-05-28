defmodule Graphql.Resolvers.Util do
  @moduledoc false

  def filter_market_by_market_ids(m, args) do
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

  def filter_market_by_exchanges(m, args) do
    case Map.has_key?(args, :exchanges) do
      true ->
        IO.inspect(args)
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

  def format_market(m) do
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

  def format_rebased_market(m) do
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
  end

  @doc """
    Returns the combined volume of a market pair across all exchanges.
  """
  defp combined_volume_across_exchanges(%{market_data: md}) do
    Enum.reduce(md, 0, fn (%{base_volume: bv}, acc) -> acc + bv end)
  end

  def format_exchanges_in_market(eim) do
    MapSet.to_list(eim)
  end
end
