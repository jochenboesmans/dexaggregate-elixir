defmodule Dexaggregatex.MarketFetching.IdexFetcher do
  @moduledoc """
  Polls the Idex market and updates the global Market accordingly.
  """
  use Task, restart: :permanent

  import Dexaggregatex.MarketFetching.{Util, Common}
  alias Dexaggregatex.MarketFetching.Structs.ExchangeMarket

  @base_api_url "https://api.idex.market"
  @market_endpoint "returnTicker"
  @currencies_endpoint "returnCurrencies"

  @poll_interval 10_000

  # Makes sure private functions are testable.
  @compile if Mix.env == :test, do: :export_all

  @doc """
  Starts an IdexFetcher process linked to the caller process.
  """
  @spec start_link(any) :: {:ok, pid}
  def start_link(_arg) do
    Task.start_link(__MODULE__, :poll, [])
  end

  @doc """
  Polls the Idex market and updates the global Market accordingly.
  """
  @spec poll() :: any
  def poll() do
    Stream.interval(@poll_interval)
    |> Stream.map(fn _x -> exchange_market() end)
    |> Enum.each(fn x -> maybe_update(x) end)
  end

  @doc """
  Fetches and formats data from the Idex API to make up the latest Idex ExchangeMarket.
  """
  @spec exchange_market() :: ExchangeMarket.t
  def exchange_market() do
    complete_market =
      case post_and_decode("#{@base_api_url}/#{@currencies_endpoint}") do
        {:ok, c} ->
          case post_and_decode("#{@base_api_url}/#{@market_endpoint}") do
            {:ok, market} ->
              Enum.reduce(market, [], fn ({k, p}, acc) ->
                %{
                  "last" => lp,
                  "highestBid" => cb,
                  "lowestAsk" => ca,
                  "baseVolume" => bv,
                } = p
                [bs, qs] = String.split(k, "_")

                ba = c[bs]["address"] |> fix_eth_address()
                qa = c[qs]["address"] |> fix_eth_address()

                case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
                  true ->
                    [generic_market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv], exchange: :idex) | acc]
                  false ->
                    acc
                end
              end)
            :error ->
              nil
          end
        :error ->
          nil
    end

    %ExchangeMarket{
      exchange: :idex,
      market: complete_market,
    }
  end

  @doc """
  Changes a specified address to the internally used eth_address if it's another representation of it.
  """
  @spec fix_eth_address(String.t) :: String.t
  defp fix_eth_address(address) do
    case address do
      "0x0000000000000000000000000000000000000000" ->
        eth_address()
      something_else ->
        something_else
    end
  end
end
