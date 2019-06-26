defmodule Dexaggregatex.API.Format do
  @moduledoc """
  Functions for formatting data to API-appropriate structures.
  """
  alias Dexaggregatex.Market.Structs.{Market, RebasedMarket, LastUpdate, Pair}
  import Dexaggregatex.Market.Util

  @doc """
  Formats a raw market into a queryable structure.
  """
  @spec format_market(Market.t) :: map
  def format_market(%Market{pairs: pairs}) do
    %{pairs: Enum.reduce(pairs, [], fn ({_k, p}, acc) -> [format_pair(p) | acc] end)}
  end

  @doc """
  Formats a rebased market into a queryable structure.
  """
  @spec format_rebased_market(RebasedMarket.t) :: map
  def format_rebased_market(%RebasedMarket{pairs: pairs, base_address: ba}) do
    fmt_pairs =
      Enum.reduce(pairs, [], fn ({_k, p}, acc) -> [format_pair(p) | acc] end)
      |> Enum.sort_by(&formatted_combined_volume_across_exchanges/1, &>=/2)

    %{base_address: ba, pairs: fmt_pairs}
  end

  @doc """
  Formats a collection of exchanges in the market into a queryable structure.
  """
  @spec format_exchanges_in_market(MapSet.t(atom)) :: [String.t]
  def format_exchanges_in_market(eim) do
    Enum.reduce(eim, [], fn (e, acc) -> [Atom.to_string(e) | acc] end)
  end

  @doc """
  Formats a last update into a queryable structure.
  """
  @spec format_last_update(LastUpdate.t) :: map
  def format_last_update(%LastUpdate{utc_time: ut, pair: pair}) do
    case pair == nil do
      true -> %{utc_time: nil, pair: nil}
      false -> %{utc_time: NaiveDateTime.to_string(ut), pair: format_pair(pair)}
    end
  end

  @spec format_pair(Pair.t) :: map
  defp format_pair(%Pair{market_data: md} = p) do
    new_p = Map.put(p, :id, pair_id(p))
    new_md =
      Enum.map(md, fn {exchange, emd} ->
        Map.put(emd, :exchange, exchange)
      end)
      |> Enum.sort_by(&(&1.base_volume), &>=/2)
    %{new_p | market_data: new_md}
  end

  @spec formatted_combined_volume_across_exchanges(Pair.t) :: number
  defp formatted_combined_volume_across_exchanges(%Pair{market_data: md}) do
    Enum.reduce(md, 0, fn (%{base_volume: bv}, acc) -> acc + bv end)
  end

end
