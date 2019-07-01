defmodule Dexaggregatex.MarketFetching.ParadexFetcher do
  @moduledoc """
  Fetches the Paradex market and updates the global Market accordingly.
  """
  use Task, restart: :permanent

  alias Dexaggregatex.MarketFetching.Structs.{Pair, ExchangeMarket, PairMarketData}
  import Dexaggregatex.Util
  import Dexaggregatex.MarketFetching.{Util, Common}

  @base_api_url "https://api.paradex.io/api/v1"
  @poll_interval 10_000

  # Make private functions testable.
  @compile if Mix.env() == :test, do: :export_all

  @doc """
  Starts a ParadexFetcher process linked to the caller process.
  """
  @spec start_link(any) :: {:ok, pid}
  def start_link(_arg) do
    Task.start_link(__MODULE__, :poll, [])
  end

  @doc """
  Polls the Paradex market and updates the global Market accordingly.
  """
  @spec poll() :: :ok
  def poll() do
    Stream.interval(@poll_interval)
    |> Stream.map(fn _x -> exchange_market() end)
    |> Enum.each(fn x -> maybe_update(x) end)
  end

  @doc """
  Fetches and formats data from the Paradex API to make up the latest Paradex ExchangeMarket.
  """
  @spec exchange_market() :: ExchangeMarket.t()
  def exchange_market() do
    pairs =
      case fetch_and_decode_with_api_key("#{@base_api_url}/markets") do
        {:ok, market} ->
          case currencies() do
            {:ok, c} ->
              Enum.reduce(market, [], fn p, acc ->
                %{"baseToken" => bs, "quoteToken" => qs, "symbol" => id} = p

                case base_volume(id) do
                  {:ok, bv} ->
                    case ticker(id) do
                      {:ok, [lp, cb, ca]} ->
                        %{^bs => ba, ^qs => qa} = c

                        case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
                          true ->
                            [
                              market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv])
                              | acc
                            ]

                          false ->
                            acc
                        end

                      :error ->
                        acc
                    end

                  :error ->
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
      exchange: :paradex,
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
        exchange: :paradex,
        last_price: safe_power(parse_float(lp), -1),
        current_bid: safe_power(parse_float(cb), -1),
        current_ask: safe_power(parse_float(ca), -1),
        base_volume: parse_float(bv)
      }
    }
  end

  @doc """
  Retrieves the currencies from the Paradex API and returns them as a simple map of symbol => address.
  """
  @spec currencies() :: {:ok, %{required(String.t()) => String.t()}} | :error
  defp currencies() do
    case fetch_and_decode_with_api_key("#{@base_api_url}/tokens") do
      {:ok, c} -> {:ok, index_currencies(c)}
      _ -> :error
    end
  end

  @doc """
  Retrieves the base volume of a token with the specified token id from the Paradex API.
  """
  @spec base_volume(String.t()) :: {:ok, binary} | :error
  defp base_volume(id) do
    case fetch_and_decode_with_api_key("#{@base_api_url}/ohlcv?market=#{id}&period=1d&amount=1") do
      {:ok, [%{"volume" => bv}]} -> {:ok, bv}
      _ -> :error
    end
  end

  @doc """
  Retrieves the ticker data of a token with the specified token id from the Paradex API.
  """
  @spec ticker(String.t()) :: {:ok, [binary]} | :error
  defp ticker(id) do
    case fetch_and_decode_with_api_key("#{@base_api_url}/ticker?market=#{id}") do
      {:ok, [%{"lastPrice" => last, "bestBid" => bid, "bestAsk" => ask}]} ->
        {:ok, [last, bid, ask]}

      _ ->
        :error
    end
  end

  @doc """
  Issues a get request to the specified url with a Paradex API key in the headers and returns the JSON-decoded response.
  """
  @spec fetch_and_decode_with_api_key(String.t()) :: {:ok, any} | :error
  defp fetch_and_decode_with_api_key(url) do
    [api_key: key] = Application.get_env(:dexaggregatex, __MODULE__, :api_key)
    fetch_and_decode(url, [{"API-KEY", key}])
  end
end
