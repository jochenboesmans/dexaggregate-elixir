defmodule Dexaggregatex.MarketFetching.OasisFetcher do
  @moduledoc """
  	Fetches the Oasis market and updates the global Market accordingly.
  """
  use Task, restart: :permanent

  alias Dexaggregatex.MarketFetching.Structs.{ExchangeMarket, Pair, PairMarketData}
  import Dexaggregatex.Util
  import Dexaggregatex.MarketFetching.{Util, Common}

  @base_api_url "https://api.oasisdex.com/v2"
  @currencies %{
    "MKR" => "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
    "WETH" => "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    "DAI" => "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
    "DGD" => "0xe0b7927c4af23765cb51314a0e0521a9645f0e2a",
    "REP" => "0x1985365e9f78359a9B6AD760e32412f4a445E862",
    "RHOC" => "0x168296bb09e24a88805cb9c33356536b980d3fc5"
  }
  @pairs [
    ["WETH", "DAI"],
    ["MKR", "WETH"],
    ["MKR", "DAI"],
    ["DGD", "WETH"],
    ["REP", "WETH"],
    ["RHOC", "WETH"]
  ]
  @poll_interval 10_000

  # Make private functions testable.
  @compile if Mix.env() == :test, do: :export_all

  @doc """
  Starts a OasisFetcher process linked to the caller process.
  """
  @spec start_link(any) :: {:ok, pid}
  def start_link(_arg) do
    Task.start_link(__MODULE__, :poll, [])
  end

  @doc """
  Polls the Oasis market and updates the global Market accordingly.
  """
  @spec poll() :: :ok
  def poll() do
    Stream.interval(@poll_interval)
    |> Stream.map(fn _x -> exchange_market() end)
    |> Enum.each(fn x -> maybe_update(x) end)
  end

  @doc """
  Fetches and formats data from the Oasis API to make up the latest Oasis ExchangeMarket.
  """
  @spec exchange_market() :: ExchangeMarket.t()
  def exchange_market() do
    c = @currencies

    pairs =
      Enum.reduce(@pairs, [], fn [bs, qs], acc ->
        case fetch_pair(base_symbol: bs, quote_symbol: qs) do
          {:ok, p} ->
            %{
              "last" => lp,
              "bid" => cb,
              "ask" => ca,
              "vol" => bv
            } = p

            [ba, qa] = [c[bs], c[qs]]

            case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
              true -> [market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) | acc]
              false -> acc
            end

          :error ->
            acc
        end
      end)

    %ExchangeMarket{
      exchange: :oasis,
      pairs: pairs
    }
  end

  @doc """
  Makes a well-formatted market pair based on the given data.
  """
  @spec market_pair(strings: [String.t()], numbers: [number]) :: Pair.t()
  defp market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
    %Pair{
      base_symbol: bs,
      quote_symbol: qs,
      base_address: ba,
      quote_address: qa,
      market_data: %PairMarketData{
        exchange: :oasis,
        last_price: safe_power(parse_float(lp), -1),
        current_bid: safe_power(parse_float(cb), -1),
        current_ask: safe_power(parse_float(ca), -1),
        base_volume: parse_float(bv)
      }
    }
  end

  @doc """
  Retrieves data of a pair with the specified base and quote symbols from the Oasis API.
  """
  @spec fetch_pair(base_symbol: String.t(), quote_symbol: String.t()) :: {:ok, map} | :error
  defp fetch_pair(base_symbol: bs, quote_symbol: qs) do
    case fetch_and_decode("#{@base_api_url}/markets/#{bs}/#{qs}") do
      {:ok, %{"data" => pair}} ->
        {:ok, pair}

      s ->
        IO.inspect(s)
        :error
    end
  end
end
