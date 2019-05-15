defmodule MarketFetching.DdexFetcher do
	@moduledoc """
		Fetches the Ddex market and updates the global Market accordingly.
	"""
	use WebSockex
	use Task

	import MarketFetching.Util
	alias MarketFetching.{Pair, ExchangeMarket, PairMarketData}

	@api_base_url "https://api.ddex.io/v3"
	@market_endpoint "markets/tickers"
	@currencies_endpoint "markets"
	@ws_url "wss://ws.ddex.io/v3"

	# Makes sure private functions are testable.
	@compile if Mix.env == :test, do: :export_all

	def start_link(_arg) do
		Task.start_link(__MODULE__, :start, [])
	end

	def start() do
		c = fetch_currencies()
		m = initial_exchange_market(c)
		maybe_update(m)
		subscribe_to_market(c)
	end

  def subscribe_to_market(c) do
    {:ok, pid} = WebSockex.start_link(@ws_url, __MODULE__, %{currencies: c})
    sub_message = %{
      type: "subscribe",
      channels: [%{
        name: "ticker",
        marketIds: c
      }]
    }
    {:ok, e} = Poison.encode(sub_message)
    WebSockex.send_frame(pid, {:text, e})
  end

	def handle_frame({:text, message},  %{currencies: c} = state) do
		{:ok, p} = Poison.decode(message)

    case try_get_valid_pair(p, c) do
      nil ->
        nil
      valid_pair ->
				IO.inspect(valid_pair)
        Market.update(valid_pair)
    end

		{:ok, state}
	end

	def handle_cast({:send, frame}, state) do
		{:reply, frame, state}
	end

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
        {:error, _message} ->
          nil
      end

    %ExchangeMarket{
      exchange: :ddex,
      market: complete_market,
    }
  end

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
        generic_market_pair([bs, qs, ba, qa, lp, cb, ca, bv], :ddex)
      false ->
        nil
    end
  end

	def fetch_market() do
		case fetch_and_decode("#{@api_base_url}/#{@market_endpoint}") do
			{:ok, %{"data" => %{"tickers" => market}}} ->
				{:ok, market}
			{:error, message} ->
				{:error, message}
		end
	end

	def fetch_currencies() do
		case fetch_and_decode("#{@api_base_url}/#{@currencies_endpoint}") do
			{:ok, %{"data" => %{"markets" => currencies}}} ->
				Enum.reduce(currencies, %{}, fn (c, acc) ->
					acc
					|> Map.put(c["baseToken"], c["baseTokenAddress"])
					|> Map.put(c["quoteToken"], c["quoteTokenAddress"])
				end)
			{:error, message} ->
				{:error, message}
		end
	end
end