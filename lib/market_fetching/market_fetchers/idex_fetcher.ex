defmodule Dexaggregatex.MarketFetching.IdexFetcher do
  @moduledoc """
  Client for the Idex market.

  * Note on Idex's WebSocket API: In order to derive most competitive rates from market orders, cancels and trades,
  an order book for each pair would have to be maintained and constantly updated.
  """
  #use WebSockex
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
  @spec poll() :: :ok
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
    pairs =
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
                  true -> [generic_market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv], exchange: :idex) | acc]
                  false -> acc
                end
              end)
            :error -> nil
          end
        :error -> nil
    end

    %ExchangeMarket{
      exchange: :idex,
      pairs: pairs,
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

  @doc """
  Currently unused WebSocket client.

  # This is public so no risk in exposing it.
  @api_key "17paIsICur8sA0OBqG6dH5G1rmrHNMwt4oNk4iX9"
  @ws_url "wss://datastream.idex.market"

  def handshake() do
    {:ok, hs} =
      %{
        "request" => "handshake",
        "payload" => %{
          "version" => "1.0.0",
          "key" => @api_key
        }
      } |> Poison.encode()
    hs
  end

  def subscribe_request(sid) do
    {:ok, sr} =
      %{
        "sid" => sid,
        "request" => "subscribeToMarkets",
        "payload" => %{
          "topics" => pairs(),
          "events" => ["market_trades"],
          "action" => "subscribe",
         }
      } |> Poison.encode()
    sr
  end

  def pairs() do
    {:ok, r} = post_and_decode("\#{@base_api_url}/\#{@market_endpoint}")
    Enum.map(r, fn {p, _data} -> p end)
    |> Enum.sort_by(fn p -> r[p]["baseVolume"] end, &>=/2)
    |> Enum.slice(0..99)
  end

  @spec start_link(any) :: {:ok, pid}
  def start_link(_arg) do
    Task.start_link(__MODULE__, :start, [])
  end

  @spec start() :: any
  def start() do
    maybe_update(exchange_market())
    subscribe_to_market()
  end

  @spec subscribe_to_market() :: any
  defp subscribe_to_market() do
    {:ok, _pid} = WebSockex.start_link(@ws_url, __MODULE__, %{sid: nil}, name: WSClient)
    WebSockex.send_frame(WSClient, {:text, handshake()})
  end

  @spec handle_frame({:text, String.t}, map) :: {:ok, map}
  def handle_frame({:text, message}, %{sid: sid} = state) do
    case Poison.decode(message) do
      {:ok, %{
        "request" => "handshake",
        "result" => "success",
        "sid" => sid
      } = m}  ->
        IO.inspect(m)
        {:reply,  {:text, subscribe_request(sid)}, %{state | sid: sid}}
      {:ok, m} ->
        IO.inspect(m)
        {:ok, state}
    end
  end

  @spec handle_cast({:send, WebSockex.frame}, map) :: {:reply, WebSockex.frame, map}
  def handle_cast({:send, frame}, state), do: {:reply, frame, state}
  """
end
