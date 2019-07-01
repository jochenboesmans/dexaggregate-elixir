defmodule Test.Dexaggregatex.MarketFetching.Common do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Dexaggregatex.MarketFetching.Common
  doctest Common

  describe "index_currencies/1" do
    @describetag :index_currencies
    test "#1: returns proper data structure on realistic input" do
      sample_currencies = [
        %{
          "address" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
          "decimals" => 18,
          "id" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
          "name" => "Ethereum",
          "symbol" => "ETH"
        },
        %{
          "address" => "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
          "decimals" => 18,
          "id" => "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
          "name" => "Wrapped Ether",
          "reserves_dest" => ["0x57f8160e1c59D16C01BbE181fD94db4E56b60495"],
          "reserves_src" => ["0x57f8160e1c59D16C01BbE181fD94db4E56b60495"],
          "symbol" => "WETH"
        }
      ]

      expected_result = %{
        "ETH" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
        "WETH" => "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
      }

      assert Common.index_currencies(sample_currencies) == expected_result
    end
  end
end
