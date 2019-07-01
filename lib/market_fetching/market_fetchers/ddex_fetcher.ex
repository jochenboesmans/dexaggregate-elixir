defmodule Dexaggregatex.MarketFetching.DdexFetcher do
  @moduledoc """
  Client for the Ddex market.
  """
  use WebSockex
  use Task

  alias Dexaggregatex.MarketFetching.Structs.{Pair, ExchangeMarket, PairMarketData}
  alias Dexaggregatex.Market
  import Dexaggregatex.MarketFetching.{Util, Common}
  import Dexaggregatex.Util

  @api_base_url "https://api.ddex.io/v3"
  @market_endpoint "markets/tickers"
  @currencies_endpoint "markets"
  @ws_url "wss://ws.ddex.io/v3"

  # Make private functions testable.
  @compile if Mix.env() == :test, do: :export_all

  @doc """
  Starts a DdexFetcher process linked to the caller process.
  """
  @spec start_link(any) :: {:ok, pid}
  def start_link(_arg) do
    Task.start_link(__MODULE__, :start, [])
  end

  @doc """
  Starts all processes to routinely get the latest Ddex market and update the global Market accordingly.
  """
  @spec start() :: :ok
  def start() do
    case currencies() do
      {:ok, fetched_currencies} ->
        maybe_update(initial_exchange_market(fetched_currencies))
        try_subscribe_to_market(fetched_currencies)

      _ ->
        start()
    end
  end

  @spec try_subscribe_to_market(map) :: :ok
  defp try_subscribe_to_market(currencies) do
    case subscribe_to_market(currencies) do
      :error -> try_subscribe_to_market(currencies)
      _ -> :ok
    end
  end

  @doc """
  Subscribes to the market at the Ddex WebSocket API.
  """
  @spec subscribe_to_market(%{required(String.t()) => String.t()}) :: any
  defp subscribe_to_market(c) do
    case pairs() do
      {:ok, p} ->
        {:ok, pid} = WebSockex.start_link(@ws_url, __MODULE__, %{currencies: c, pairs: p})

        sub_message = %{
          type: "subscribe",
          channels: [
            %{
              name: "ticker",
              marketIds: p
            }
          ]
        }

        {:ok, e} = Poison.encode(sub_message)
        WebSockex.send_frame(pid, {:text, e})

      :error ->
        :error
    end
  end

  @doc """
  Handles all incoming text messages from a subscription, updating the global market when it's market data.
  """
  @spec handle_frame({:text, String.t()}, map) :: {:ok, map}
  @impl true
  def handle_frame({:text, message}, %{currencies: c} = state) do
    {:ok, p} = Poison.decode(message)

    case p do
      %{"type" => "subscriptions"} ->
        nil

      %{"type" => "ticker"} ->
        case try_get_valid_pair(p, c) do
          :error -> nil
          {:ok, valid_pair} -> Market.Client.update(valid_pair)
        end

      _ ->
        nil
    end

    {:ok, state}
  end

  @doc """
  Handles all send frame casts, sending the frame to the WebSocket endpoint.
  """
  @spec handle_cast({:send, WebSockex.frame()}, map) :: {:reply, WebSockex.frame(), map}
  @impl true
  def handle_cast({:send, frame}, state), do: {:reply, frame, state}

  @doc """
  Fetches and formats data from the Ddex REST API to make up the latest Ddex ExchangeMarket.
  """
  @spec initial_exchange_market(%{required(String.t()) => String.t()}) :: ExchangeMarket.t()
  def initial_exchange_market(c) do
    fetched_pairs =
      case market() do
        {:ok, m} ->
          Enum.reduce(m, [], fn p, acc ->
            case try_get_valid_pair(p, c) do
              {:ok, valid_pair} -> [valid_pair | acc]
              :error -> acc
            end
          end)

        :error ->
          nil
      end

    %ExchangeMarket{
      exchange: :ddex,
      pairs: fetched_pairs
    }
  end

  @spec try_get_valid_pair(map, %{required(String.t()) => String.t()}) :: {:ok, Pair.t()} | :error
  def try_get_valid_pair(p, c) do
    %{
      "price" => lp,
      "bid" => cb,
      "ask" => ca,
      "volume" => bv,
      "marketId" => id
    } = p

    [bs, qs] = String.split(id, "-")
    [ba, qa] = [c[bs], c[qs]]

    case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
      true -> {:ok, market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv])}
      false -> :error
    end
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
        exchange: :ddex,
        last_price: safe_power(parse_float(lp), -1),
        current_bid: safe_power(parse_float(cb), -1),
        current_ask: safe_power(parse_float(ca), -1),
        base_volume: parse_float(bv)
      }
    }
  end

  @doc """
  Retrieves the currencies from the Ddex REST API and returns them as a simple map of symbol => address.
  """
  @spec currencies() :: {:ok, %{required(String.t()) => String.t()}} | :error
  defp currencies() do
    case fetch_and_decode("#{@api_base_url}/#{@currencies_endpoint}") do
      {:ok, %{"data" => %{"markets" => retrieved_currencies}}} ->
        {:ok,
         Enum.reduce(retrieved_currencies, %{}, fn c, acc ->
           acc
           |> Map.put(c["baseToken"], c["baseTokenAddress"])
           |> Map.put(c["quoteToken"], c["quoteTokenAddress"])
         end)}

      _ ->
        :error
    end
  end

  @doc """
  Retrieves the market from the Ddex REST API.
  """
  @spec market() :: {:ok, [map]} | :error
  def market() do
    case fetch_and_decode("#{@api_base_url}/#{@market_endpoint}") do
      {:ok, %{"data" => %{"tickers" => m}}} ->
        {:ok, m}

      _ ->
        :error
    end
  end

  @doc """
  Retrieves the pairs from the Ddex REST API and returns a list of their IDs.
  """
  @spec pairs() :: {:ok, [String.t()]} | :error
  def pairs() do
    case fetch_and_decode("#{@api_base_url}/#{@currencies_endpoint}") do
      {:ok, %{"data" => %{"markets" => markets}}} ->
        {:ok, Enum.map(markets, fn p -> p["id"] end)}

      _ ->
        :error
    end
  end
end
