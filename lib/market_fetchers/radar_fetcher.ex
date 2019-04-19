defmodule RadarFetcher do
	@moduledoc """
	Fetches the Radar Relay market.
	"""
	use GenServer

	def start_link(_initial_state) do
		GenServer.start_link(__MODULE__, [%{}], name: __MODULE__)
	end

	@impl true
	def init(_initial_market) do
		{:ok, poll()}
	end

	@impl true
	def handle_call(:get, _from, market) do
		{:reply, market, market}
	end

	@impl true
	def handle_cast({:update, new_market}, _market) do
		{:noreply, new_market}
	end

	def get_market() do
		GenServer.call(__MODULE__, :get)
	end

	def poll() do
		Stream.interval(10_000)
		|> Stream.map(fn _x -> complete_market() end)
		|> Enum.each(fn x -> Market.update(x) end)
	end

	def complete_market() do
		complete_market = Enum.map(market(), fn p ->
			%Pair{
				base_symbol: p.base_symbol,
				quote_symbol: p.quote_symbol,
				base_address: p.base_address,
				quote_address: p.quote_address,
				market_data: p.market_data,
			}
		end)

		%ExchangeMarket{
			exchange: :radar,
			market: complete_market
		}
	end

	defp market() do
		fetch_market()
		|> transform_market()
	end

	defp eth_address() do
		"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	end

	def fetch_market() do
		fetch_and_decode("https://api.radarrelay.com/v2/markets?include=base,ticker,stats")
	end

	defp fetch_and_decode(url) do
		%HTTPoison.Response{body: received_body} = HTTPoison.get!(url)

		case Poison.decode(received_body) do
			{:ok, decoded_market} ->
				decoded_market
			{:error, _message} ->
				nil
		end
	end

	def transform_market(market) do
		eth_address = eth_address()

		Enum.map(market, fn p ->
			[q, b] = String.split(p["id"], "-")
			%Pair{
				base_symbol: b,
				quote_symbol: q,
				base_address: p["baseTokenAddress"],
				quote_address: p["quoteTokenAddress"],
				market_data: %PairMarketData{
					last_traded: elem(Float.parse(p["ticker"]["price"]), 0),
					current_bid: elem(Float.parse(p["ticker"]["bestBid"]), 0),
					current_ask: elem(Float.parse(p["ticker"]["bestAsk"]), 0),
					base_volume: elem(Float.parse(p["stats"]["volume24Hour"]), 0),
					quote_volume: nil,
				}
			}
		end)
	end
end