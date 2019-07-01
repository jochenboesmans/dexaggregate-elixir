defmodule Dexaggregatex.Market.Rebasing do
  @moduledoc """
  Logic for rebasing pairs of a market to a token, denominating all rates in this token.
  """
  alias Dexaggregatex.Market.Structs.{Market, ExchangeMarketData, Pair, RebasedMarket}
  alias Dexaggregatex.Market.Rebasing
  alias Dexaggregatex.Market.Rebasing.Neighbors
  import Dexaggregatex.Market.Util
  import Dexaggregatex.Util

  # Makes sure private functions are testable.
  @compile if Mix.env() == :test, do: :export_all

  @doc """
  Rebases all pairs in a given market to a token with a given rebase_address.
  """
  @spec rebase_market(Market.t(), String.t(), integer) :: RebasedMarket.t()
  def rebase_market(%Market{pairs: pairs} = m, rebase_address, max_depth) do
    rebased_pairs =
      case Rebasing.Cache.get({:rebase_market, {rebase_address, max_depth}}) do
        {:found, cached_market} ->
          cached_market

        {:not_found, _} ->
          created_tasks =
            Enum.map(pairs, fn {pair_id, p} ->
              {pair_id, Task.async(fn -> rebase_pair(p, m, rebase_address, max_depth) end)}
            end)

          rebased_market =
            Enum.reduce(created_tasks, %{}, fn {k, p}, acc ->
              result = Task.await(p, 60_000)
              Map.put(acc, k, result)
            end)

          Rebasing.Cache.add({:rebase_market, {rebase_address, max_depth}}, rebased_market)
          rebased_market
      end

    %RebasedMarket{
      pairs: rebased_pairs,
      base_address: rebase_address
    }
  end

  @doc """
  Rebases all market data for a given pair to the given rebase_address.
  """
  @spec rebase_pair(Pair.t(), Market.t(), String.t(), integer) :: Pair.t()
  def rebase_pair(
        %Pair{market_data: pmd} = p,
        %Market{pairs: pairs} = m,
        rebase_address,
        max_depth
      ) do
    rebased_pmd =
      Enum.reduce(pmd, %{}, fn {exchange_id, emd}, acc ->
        p_id = pair_id(p)

        rebase_paths = %{
          base: try_expand_path([p_id], rebase_address, max_depth, pairs, :base),
          quote: try_expand_path([p_id], rebase_address, max_depth, pairs, :quote)
        }

        rebased_emd = %{
          emd
          | last_price: deeply_rebase_rate(emd.last_price, rebase_address, m, rebase_paths),
            current_bid: deeply_rebase_rate(emd.current_bid, rebase_address, m, rebase_paths),
            current_ask: deeply_rebase_rate(emd.current_ask, rebase_address, m, rebase_paths),
            base_volume: deeply_rebase_rate(emd.base_volume, rebase_address, m, rebase_paths)
        }

        Map.put(acc, exchange_id, rebased_emd)
      end)

    %{p | market_data: rebased_pmd}
  end

  @doc """
  Expands the given path_to_expand, if necessary, by finding neighbors in the specified direction.
  """
  @spec try_expand_path([String.t()], String.t(), integer, map, :base | :quote) :: [String.t()]
  defp try_expand_path(
         [last_p_id | _] = path_to_expand,
         rebase_address,
         max_depth,
         pairs,
         direction
       ) do
    %Pair{base_address: last_ba} = pairs[last_p_id]

    cond do
      last_ba == rebase_address -> [path_to_expand]
      Enum.count(path_to_expand) >= max_depth -> []
      true -> expand_path(path_to_expand, rebase_address, max_depth, pairs, direction)
    end
  end

  @doc """
  Returns a list of all paths that expand the given path_to_expand, by expanding in the specified direction.
  """
  @spec expand_path([String.t()], String.t(), integer, map, :base | :quote) :: [String.t()]
  defp expand_path([last_p_id | _] = path_to_expand, rebase_address, max_depth, pairs, direction) do
    case direction do
      :base -> Neighbors.get_neighbors(:base, last_p_id)
      :quote -> Neighbors.get_neighbors(:quote, last_p_id)
    end

    # Make list of all paths that expand the one pair expanded paths.
    |> Enum.reduce([], fn n_p_id, paths_acc ->
      try_expand_path([n_p_id | path_to_expand], rebase_address, max_depth, pairs, direction) ++
        paths_acc
    end)
  end

  @doc """
  Deeply rebases a given rate of a given token in the market as the volume-weighted rate of all possible paths
  from the given pair to the given rebase_address.
  """
  @spec deeply_rebase_rate(number, String.t(), Market.t(), %{
          base: [String.t()],
          quote: [String.t()]
        }) :: number
  defp deeply_rebase_rate(rate, rebase_address, %Market{pairs: pairs}, %{base: brp, quote: qrp}) do
    r =
      Enum.reduce(brp, %{combined_volume: 0, volume_weighted_sum: 0}, fn base_rebase_path, sums ->
        base_update_sums(sums, base_rebase_path, rate, pairs, rebase_address)
      end)

    %{combined_volume: cv, volume_weighted_sum: vws} =
      Enum.reduce(qrp, r, fn quote_rebase_path, sums ->
        quote_update_sums(sums, quote_rebase_path, rate, pairs, rebase_address)
      end)

    safe_div(vws, cv)
  end

  @doc """
  Updates the given volume-weighted-rate-determining sums based on the given base rebase path.
  """
  @spec base_update_sums(
          %{combined_volume: number, volume_weighted_sum: number},
          [String.t()],
          number,
          map,
          String.t()
        ) ::
          %{combined_volume: number, volume_weighted_sum: number}
  defp base_update_sums(sums, brp, original_rate, pairs, rebase_address) do
    path_length = Enum.count(brp)
    max_i = path_length - 1

    brp_wi = Enum.with_index(brp)
    # Rebase the original_rate for every pair of the rebase_path.
    # Iterate through the rebase_path starting from the original_pair, going to the pair based in rebase_address,
    # 	rebasing the original_rate to the base_address of all pairs that aren't the original one.
    # Calculate each involved pair's combined volume and rebase it in the base address of the ultimate rebase pair.
    # This rebase_path's weight is the average volume of all involved pairs except the original one.
    %{rate: rebased_rate, weighted_sum: ws} =
      List.foldr(brp_wi, %{rate: original_rate, weighted_sum: 0}, fn {rp_id, i},
                                                                     %{rate: r, weighted_sum: ws} =
                                                                       acc ->
        p = %Pair{base_address: rp_ba, quote_address: rp_qa} = pairs[rp_id]

        case i === max_i do
          true ->
            # Keep original_rate since it's already based in the original pair's base address.
            # Exclude volumes of start pair for weight.
            acc

          false ->
            # Rebase the rate currently based in this pair's quote address (previous pair's base address)
            # to this pair's base address.
            %{
              acc
              | rate: rebase_rate(r, rp_ba, rp_qa, pairs),
                weighted_sum:
                  ws +
                    (combined_volume_across_exchanges(p)
                     |> rebase_rate(rebase_address, rp_ba, pairs))
            }
        end
      end)

    weight = weighted_average(%{weighted_sum: ws}, path_length)

    %{
      sums
      | volume_weighted_sum: sums.volume_weighted_sum + weight * rebased_rate,
        combined_volume: sums.combined_volume + weight
    }
  end

  @doc """
  Updates the given volume-weighted-rate-determining sums based on the given quote rebase path.
  """
  @spec quote_update_sums(
          %{combined_volume: number, volume_weighted_sum: number},
          [String.t()],
          number,
          map,
          String.t()
        ) ::
          %{combined_volume: number, volume_weighted_sum: number}
  defp quote_update_sums(sums, qrp, original_rate, pairs, rebase_address) do
    path_length = Enum.count(qrp)
    max_i = path_length - 1

    qrp_wi = Enum.with_index(qrp)
    # Rebase the original_rate for every pair of the rebase_path.
    # Iterate through the rebase_path starting from the original_pair, going to the pair based in rebase_address,
    # 	rebasing the original_rate to the base_address of all pairs that aren't the last one.
    %{rate: rebased_rate, weighted_sum: ws} =
      List.foldr(qrp_wi, %{rate: original_rate, weighted_sum: 0}, fn {rp_id, i},
                                                                     %{rate: r, weighted_sum: ws} =
                                                                       acc ->
        p = %Pair{base_address: rp_ba, quote_address: rp_qa} = pairs[rp_id]

        cond do
          i !== 0 && i !== max_i ->
            # Rebase the rate currently based in this pair's base address
            # to this pair's quote address (next pair's base address).
            %{
              acc
              | rate: rebase_rate(r, rp_qa, rp_ba, pairs),
                weighted_sum:
                  ws +
                    (combined_volume_across_exchanges(p)
                     |> rebase_rate(rebase_address, rp_ba, pairs))
            }

          i === 0 ->
            # Keep rate since it's already based in the rebase address.
            %{
              acc
              | weighted_sum:
                  ws +
                    (combined_volume_across_exchanges(p)
                     |> rebase_rate(rebase_address, rp_ba, pairs))
            }

          i === max_i ->
            # Keep weighted_sum since original pair is same for all paths.
            %{acc | rate: rebase_rate(r, rp_qa, rp_ba, pairs)}
        end
      end)

    weight = weighted_average(%{weighted_sum: ws}, path_length - 1)

    %{
      sums
      | volume_weighted_sum: sums.volume_weighted_sum + weight * rebased_rate,
        combined_volume: sums.combined_volume + weight
    }
  end

  @doc """
  Rebases a given rate of a pair based in a token with a given base_address to a token with a given rebase_address.

  	## Examples
  		iex> dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
  		iex> eth_address = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  		iex> sample_market = %{
  		...>  Dexaggregatex.Market.Util.pair_id(dai_address, eth_address) =>
  		...>	%Dexaggregatex.Market.Structs.Pair{
  		...>    base_symbol: "DAI",
  		...>		quote_symbol: "ETH",
  		...>		quote_address: eth_address,
  		...>		base_address: dai_address,
  		...>		market_data: %{:oasis =>
  		...>      %Dexaggregatex.Market.Structs.ExchangeMarketData{
  		...>			  last_price: 200,
  		...>			  current_bid: 195,
  		...>			  current_ask: 205,
  		...>			  base_volume: 100_000,
  		...>				timestamp: :os.system_time(:millisecond)
  		...>		  }
  		...>	  }
  		...>  }
  		...> }
  		iex> trunc(Dexaggregatex.Market.Rebasing.rebase_rate(100, dai_address, eth_address, sample_market))
  		20_000
  """
  @spec rebase_rate(number, String.t(), String.t(), map) :: number
  defp rebase_rate(rate, rebase_address, base_address, pairs) do
    case rebase_address == base_address do
      true ->
        rate

      false ->
        rebase_pair_id = pair_id(rebase_address, base_address)

        case Map.has_key?(pairs, rebase_pair_id) do
          true -> rate * volume_weighted_spread_average(pairs[rebase_pair_id])
          false -> 0
        end
    end
  end
end
