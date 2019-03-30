defmodule IdexFetcher do
	@moduledoc """
	Fetches the Idex market.
	"""
	use Task
	alias MarketFetchers.Structs.Pair
	alias MarketFetchers.Structs.PairMarketData
	alias MarketFetchers.Structs.Currency

	def start_link(_arg) do
		Task.start_link(&poll/0)
	end

	def poll() do
		receive do
		after
			10_000 ->
				transform_market(fetch_market())
				|> add_currency_addresses()
				|> IO.inspect()
				poll()
		end
	end

	def add_currency_addresses(market) do
		currencies = transform_currencies(fetch_currencies())
		Enum.map(market, fn p ->
			%Pair{
				base_symbol: p.base_symbol,
				quote_symbol: p.quote_symbol,
				base_address: currencies[p.base_symbol],
				quote_address: currencies[p.quote_symbol],
				market_data: p.market_data
			}
		end)
	end

	def fetch_currencies() do
		fetch_and_decode("https://api.idex.market/returnCurrencies")
	end

	def fetch_market() do
		fetch_and_decode("https://api.idex.market/returnTicker")
	end

	def fetch_and_decode(url) do
		%HTTPoison.Response{body: received_body} = HTTPoison.post!(url, Poison.encode!(%{}))
		case (Poison.decode(received_body)) do
			{:ok, data} ->
				data
			{:error, _message} ->
				nil
		end
	end

	defp valid_float?(float) do
		case float do
			:error -> false
			{0.0, ""} -> false
			{_valid_value, ""} -> true
		end
	end

	def transform_market(market) do
		market
		|> Enum.filter(fn {_k, p} ->
			values_to_check = [p["last"], p["highestBid"], p["lowestAsk"], p["baseVolume"], p["quoteVolume"]]
			Enum.all?(values_to_check, fn v -> valid_float?(Float.parse(v)) end)
		end)
		|> Enum.map(fn {k, p} ->
			[base_symbol, quote_symbol] = String.split(k, "_")
			%Pair{
				base_symbol: base_symbol,
				quote_symbol: quote_symbol,
				base_address: "",
				quote_address: "",
				market_data: %PairMarketData{
					last_traded: elem(Float.parse(p["last"]), 0),
					current_bid: elem(Float.parse(p["highestBid"]), 0),
					current_ask: elem(Float.parse(p["lowestAsk"]), 0),
					base_volume: elem(Float.parse(p["baseVolume"]), 0),
					quote_volume: elem(Float.parse(p["quoteVolume"]), 0)
				}
			}
		end)
	end

	def transform_currencies(currencies) do
		result = Enum.reduce(currencies, %{}, fn ({k, c}, acc) ->
			Map.put(acc, k, c["address"])
		end)
	end

end
