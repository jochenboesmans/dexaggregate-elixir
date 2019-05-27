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
        Enum.reduce(m, %{}, fn ({k, %{market_data: md} = p}, acc1) ->
          filtered_pmd = Enum.reduce(md, [], fn (%{exchange: e}, acc2) ->
            case Enum.member?(args.exchanges, e) do
              true ->
                [e | acc2]
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
      new_md = Enum.map(p.market_data, fn {exchange, emd} ->
        Map.put(emd, :exchange, exchange)
      end) |> Enum.sort_by(fn md -> md.base_volume end, &>=/2)

      [%{new_p | market_data: new_md} | acc]
    end)
  end

end
