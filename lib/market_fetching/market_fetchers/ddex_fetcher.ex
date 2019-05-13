defmodule MarketFetching.DdexFetcher do
	@moduledoc """
		Fetches the Ddex market and updates the global Market accordingly.
	"""

	use WebSockex

	import MarketFetching.Util

	alias MarketFetching.Pair, as: Pair
	alias MarketFetching.ExchangeMarket, as: ExchangeMarket
	alias MarketFetching.PairMarketData, as: PairMarketData

	@api_base_url "https://api.ddex.io/v3"
	@market_endpoint "markets/tickers"
	@currencies_endpoint "markets"
	@ws_url "wss://ws.ddex.io/v3"

	# Makes sure private functions are testable.
	@compile if Mix.env == :test, do: :export_all

	def start_link(_arg) do
		c = fetch_currencies()
		Market.update(initial_exchange_market(c))
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
		try_add_received_pair(p, c)
		{:ok, state}
	end

	def handle_cast({:send, frame}, state) do
		{:reply, frame, state}
	end

	def try_add_received_pair(p, c) do
		%{
			"price" => lp,
			"bid" => cb,
			"ask" => ca,
			"volume" => bv,
			"marketId" => id,
		} = p
		[bs, qs] = String.split(id, "-")
		[ba, qa] = [c[bs], c[qs]]

		case valid_values?([bs, qs, ba, qa], [bv, lp, cb, ca]) do
			true ->
				valid_pair = %Pair{
					base_symbol: bs,
					quote_symbol: qs,
					base_address: ba,
					quote_address: qa,
					market_data: %PairMarketData{
						exchange: :ddex,
						last_price: parse_float(lp),
						current_bid: parse_float(cb),
						current_ask: parse_float(ca),
						base_volume: parse_float(bv),
					}
				}
				Market.update(valid_pair)
			false ->
				nil
		end
	end

	def initial_exchange_market(c) do
		fetch_market()
		|> assemble_exchange_market(c)
	end

	defp assemble_exchange_market(market, currencies) do
		complete_market =
			Enum.reduce(market, [], fn (p, acc) ->
				%{
					"price" => lp,
					"bid" => cb,
					"ask" => ca,
					"volume" => bv,
					"marketId" => id,
				} = p
				[bs, qs] = String.split(id, "-")
				[ba, qa] = [currencies[bs], currencies[qs]]

				case valid_values?([bs, qs, ba, qa], [bv, lp, cb, ca]) do
					true ->
						valid_pair = %Pair{
							base_symbol: bs,
							quote_symbol: qs,
							base_address: ba,
							quote_address: qa,
							market_data: %PairMarketData{
								exchange: :ddex,
								last_price: parse_float(lp),
								current_bid: parse_float(cb),
								current_ask: parse_float(ca),
								base_volume: parse_float(bv),
							}
						}
						[valid_pair | acc]
					false ->
						acc
				end
			end)

		%ExchangeMarket{
			exchange: :ddex,
			market: complete_market,
		}
	end



	def fetch_market() do
		case fetch_and_decode("#{@api_base_url}/#{@market_endpoint}") do
			{:ok, %{"tickers" => data}} ->
				data
			{:error, _message} ->
				nil
		end
	end

	def fetch_currencies() do
		case fetch_and_decode("#{@api_base_url}/#{@currencies_endpoint}") do
			{:ok, %{"markets" => currencies}} ->
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