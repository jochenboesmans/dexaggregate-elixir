defmodule Dexaggregatex.MarketFetching.DdexFetcher do
	@moduledoc """
	Fetches the Ddex market and updates the global Market accordingly.
	"""
  use WebSockex
	use Task

	alias Dexaggregatex.MarketFetching.Structs.{Pair, ExchangeMarket, PairMarketData}
	alias Dexaggregatex.Market

	import Dexaggregatex.MarketFetching.{Util, Common}

	# Makes sure private functions are testable.
	@compile if Mix.env == :test, do: :export_all

	@api_base_url "https://api.ddex.io/v3"
	@market_endpoint "markets/tickers"
	@currencies_endpoint "markets"
  @ws_url "wss://ws.ddex.io/v3"

	def start_link(_arg) do
		Task.start_link(__MODULE__, :start, [])
	end

	def start() do
		c = case fetch_currencies() do
			{:ok, currencies} -> currencies
			:error -> nil
		end
		maybe_update(initial_exchange_market(c))
    subscribe_to_market(c)
	end

  def subscribe_to_market(c) do
    m =
			case fetch_pairs() do
				{:ok, pairs} -> pairs
				:error -> []
			end
    {:ok, pid} = WebSockex.start_link(@ws_url, __MODULE__, %{currencies: c, pairs: m})
    sub_message = %{
      type: "subscribe",
      channels: [%{
        name: "ticker",
        marketIds: m
      }]
    }
    {:ok, e} = Poison.encode(sub_message)
    WebSockex.send_frame(pid, {:text, e})
  end

  def handle_frame({:text, message}, %{currencies: c} = state) do
    {:ok, p} = Poison.decode(message)

    case p do
      nil ->
        nil
      %{
        "type" => "subscriptions"
      } ->
        nil
      %{
        "type" => "ticker"
      } ->
        case try_get_valid_pair(p, c) do
          nil -> nil
          valid_pair -> Market.update(valid_pair)
        end
      _ ->
        nil
    end

    {:ok, state}
  end

  def handle_cast({:send, frame}, state) do
    {:reply, frame, state}
  end

	@spec initial_exchange_market(map) :: ExchangeMarket.t
  def initial_exchange_market(c) do
    complete_market =
      case fetch_market() do
        {:ok, market} ->
          Enum.reduce(market, [], fn (p, acc) ->
            case try_get_valid_pair(p, c) do
              nil -> acc
              valid_pair -> [valid_pair | acc]
            end
          end)
				:error ->
          nil
      end

    %ExchangeMarket{
      exchange: :ddex,
      market: complete_market,
    }
  end

	@spec try_get_valid_pair(map, map) :: Pair.t | nil
	def try_get_valid_pair(p, c) do
		%{
			"price" => lp,
			"bid" => cb,
			"ask" => ca,
			"volume" => bv,
			"marketId" => id,
		} = p
		[bs, qs] = String.split(id, "-")
		[ba, qa] = [c[bs], c[qs]]

    case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
      true ->
        market_pair([bs, qs, ba, qa, lp, cb, ca, bv])
      false ->
        nil
    end
  end

	@spec market_pair([String.t | number]) :: Pair.t
	defp market_pair([bs, qs, ba, qa, lp, cb, ca, bv]) do
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

	@spec fetch_market() :: {:ok, [any]} | :error
	def fetch_market() do
		case fetch_and_decode("#{@api_base_url}/#{@market_endpoint}") do
			{:ok, %{"data" => %{"tickers" => market}}} ->
				{:ok, market}
			:error ->
				:error
		end
	end

	@spec fetch_pairs() :: {:ok, [String.t]} | :error
  def fetch_pairs() do
    case fetch_and_decode("#{@api_base_url}/#{@currencies_endpoint}") do
      {:ok, %{"data" => %{"markets" => markets}}} ->
				{:ok, Enum.map(markets, fn p -> p["id"] end)}
			:error ->
				:error
    end
  end

	@spec fetch_currencies() :: {:ok, map} | :error
	def fetch_currencies() do
		case fetch_and_decode("#{@api_base_url}/#{@currencies_endpoint}") do
			{:ok, %{"data" => %{"markets" => currencies}}} ->
				{:ok, Enum.reduce(currencies, %{}, fn (c, acc) ->
					acc
					|> Map.put(c["baseToken"], c["baseTokenAddress"])
					|> Map.put(c["quoteToken"], c["quoteTokenAddress"])
				end)}
			:error ->
				:error
		end
	end
end