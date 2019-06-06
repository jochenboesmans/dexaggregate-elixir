defmodule Dexaggregatex.MarketFetching.IdexFetcher do
  @moduledoc """
  Fetches the Idex market and updates the global Market accordingly.
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

  def start_link(_arg) do
    Task.start_link(__MODULE__, :poll, [])
  end

  def poll() do
    Stream.interval(@poll_interval)
    |> Stream.map(fn _x -> exchange_market() end)
    |> Enum.each(fn x -> maybe_update(x) end)
  end

  @spec exchange_market() :: ExchangeMarket.t()
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

                ba =
                  case c[bs]["address"] do
                    "0x0000000000000000000000000000000000000000" ->
                      "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
                    something_else ->
                      something_else
                  end
                qa = c[qs]["address"]

                case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
                  true ->
                    [generic_market_pair([bs, qs, ba, qa, lp, cb, ca, bv], :idex) | acc]
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
end
