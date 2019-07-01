defmodule Dexaggregatex.Market.Util do
  @moduledoc """
  Generic functions used for maintaining the market model.
  """
  alias Dexaggregatex.Market.Structs.{Pair, ExchangeMarketData}
  import Dexaggregatex.Util

  @doc """
  Determines the internal id of a Market.Pair.
  """
  @spec pair_id(Pair.t()) :: String.t()
  def pair_id(%Pair{base_address: ba, quote_address: qa}) do
    Base.encode64(:crypto.hash(:sha512, "#{ba}/#{qa}"))
  end

  @doc """
  Determines the internal id of a Market.Pair based on its base and quote address.
  """
  @spec pair_id(String.t(), String.t()) :: String.t()
  def pair_id(ba, qa) do
    Base.encode64(:crypto.hash(:sha512, "#{ba}/#{qa}"))
  end

  @doc """
  Calculates a volume-weighted average of the current bids and asks of a given pair across all exchanges.

  	## Examples
  		iex> dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
  		iex> eth_address = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  		iex> eth_dai = %Dexaggregatex.Market.Structs.Pair{
  		...>    base_symbol: "DAI",
  		...>		quote_symbol: "ETH",
  		...>		quote_address: eth_address,
  		...>		base_address: dai_address,
  		...>		market_data: %{
  		...>			:oasis => %Dexaggregatex.Market.Structs.ExchangeMarketData{
  		...>			  last_price: 0,
  		...>			  current_bid: 200,
  		...>			  current_ask: 400,
  		...>			  base_volume: 1,
  		...>				timestamp: :os.system_time(:millisecond)
  		...>		  },
  		...>			:kyber => %Dexaggregatex.Market.Structs.ExchangeMarketData{
  		...>				last_price: 0,
  		...>				current_bid: 150,
  		...>				current_ask: 300,
  		...>				base_volume: 4,
  		...>				timestamp: :os.system_time(:millisecond)
  		...>			}
  		...>	  }
  		...>  }
  		iex> Dexaggregatex.Market.Util.volume_weighted_spread_average(eth_dai)
  		240.0
  """
  @spec volume_weighted_spread_average(Pair.t()) :: float
  def volume_weighted_spread_average(%Pair{market_data: pmd} = p) do
    %{
      current_bids:
        Enum.reduce(pmd, 0, fn {_eid, %ExchangeMarketData{base_volume: bv, current_bid: cb}},
                               sum ->
          sum + bv * cb
        end),
      current_asks:
        Enum.reduce(pmd, 0, fn {_eid, %ExchangeMarketData{base_volume: bv, current_ask: ca}},
                               sum ->
          sum + bv * ca
        end)
    }
    |> weighted_average(combined_volume_across_exchanges(p))
  end

  @doc """
  Calculates the combined volume across all exchanges of a given token in the market,
  denominated in the base token of the market pair.

  	## Examples
  		iex> dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
  		iex> eth_address = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  		iex> dai_eth = %Dexaggregatex.Market.Structs.Pair{
  		...>    base_symbol: "DAI",
  		...>		quote_symbol: "ETH",
  		...>		quote_address: eth_address,
  		...>		base_address: dai_address,
  		...>		market_data: %{
  		...>			:oasis => %Dexaggregatex.Market.Structs.ExchangeMarketData{
  		...>			  last_price: 0,
  		...>			  current_bid: 0,
  		...>			  current_ask: 0,
  		...>			  base_volume: 100,
  		...>				timestamp: :os.system_time(:millisecond)
  		...>		  },
  		...>			:kyber => %Dexaggregatex.Market.Structs.ExchangeMarketData{
  		...>				last_price: 0,
  		...>				current_bid: 0,
  		...>				current_ask: 0,
  		...>				base_volume: 150,
  		...>				timestamp: :os.system_time(:millisecond)
  		...>			}
  		...>	  }
  		...>  }
  		iex> Dexaggregatex.Market.Util.combined_volume_across_exchanges(dai_eth)
  		250
  """
  @spec combined_volume_across_exchanges(Pair.t()) :: number
  def combined_volume_across_exchanges(%Pair{market_data: pmd}) do
    Enum.reduce(pmd, 0, fn {_exchange_id, %ExchangeMarketData{base_volume: bv}}, sum ->
      sum + bv
    end)
  end
end
