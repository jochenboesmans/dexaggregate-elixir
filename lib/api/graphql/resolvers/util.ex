defmodule Graphql.Resolvers.Util do
  @moduledoc false

  def filter_market_by_market_ids(m, ids) do
    case ids != nil do
      true ->
        Enum.reduce(m, %{}, fn ({k, p}, acc) ->
          case Enum.member?(ids, k) do
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

  def filter_market_by_exchanges(m, exchanges) do
    case exchanges != nil do
      true ->
        Enum.reduce(m, %{}, fn ({k, %{market_data: md} = p}, acc1) ->
          filtered_pmd = Enum.reduce(md, [], fn (%{exchange: e}, acc2) ->
            case Enum.member?(exchanges, e) do
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
end
