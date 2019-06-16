defmodule Dexaggregatex.API.Format do
  @moduledoc """
  Functions for formatting data to API-appropriate structures.
  """

  alias Dexaggregatex.Market.Structs.{Market, RebasedMarket, LastUpdate, Pair}
  import  Dexaggregatex.Market.Util

  @spec format_market(Market.t) :: Market.t
  def format_market(%Market{pairs: pairs} = m) do
    fmt_pairs =
      Enum.reduce(pairs, [], fn ({k, %Pair{market_data: md} = p}, acc) ->
        new_p = Map.put(p, :id, k)
        new_md =
          Enum.map(md, fn {exchange, emd} ->
            Map.put(emd, :exchange, exchange)
          end)
          |> Enum.sort_by(&(&1.base_volume), &>=/2)

        [%{new_p | market_data: new_md} | acc]
      end)
    %{m | pairs: fmt_pairs}
  end

  @spec format_rebased_market(RebasedMarket.t) :: RebasedMarket.t
  def format_rebased_market(%RebasedMarket{pairs: pairs} = rm) do
    fmt_pairs =
      Enum.reduce(pairs, [], fn ({k, p}, acc) ->
        new_p = Map.put(p, :id, k)
        new_md =
          Enum.map(p.market_data, fn {exchange, emd} ->
            Map.put(emd, :exchange, exchange)
          end)
          |> Enum.sort_by(&(&1.base_volume), &>=/2)
        [%{new_p | market_data: new_md} | acc]
      end)
      |> Enum.sort_by(&combined_volume_across_exchanges/1, &>=/2)

    %{rm | pairs: fmt_pairs}
  end

  @spec format_exchanges_in_market(MapSet.t(atom)) :: [String.t]
  def format_exchanges_in_market(eim) do
    Enum.reduce(eim, [], fn (e, acc) -> [Atom.to_string(e) | acc] end)
  end

  @spec format_last_update(LastUpdate.t) :: map
  def format_last_update(%LastUpdate{utc_time: ut, pair: pair}) do
    case pair == nil do
      true ->
        %{
          utc_time: nil,
          pair: nil
        }
      false ->
        new_p = Map.put(pair, :id, pair_id(pair))
        new_md =
          Enum.map(pair.market_data, fn {exchange, emd} ->
            Map.put(emd, :exchange, exchange)
          end)
          |> Enum.sort_by(&(&1.base_volume), &>=/2)
        fmt_p = %{new_p | market_data: new_md}

        %{
          utc_time: NaiveDateTime.to_string(ut),
          pair: fmt_p
        }
    end
  end

  @spec combined_volume_across_exchanges(Pair.t) :: number
  defp combined_volume_across_exchanges(%Pair{market_data: md}) do
    Enum.reduce(md, 0, fn (%{base_volume: bv}, acc) -> acc + bv end)
  end

end
