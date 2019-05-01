defmodule MarketFetching.TokenstoreFetcher do
	@moduledoc """
		Fetches the Tokenstore market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent
	alias MarketFetching.Util, as: Util
	alias MarketFetching.Pair, as: Pair
	alias MarketFetching.ExchangeMarket, as: ExchangeMarket
	alias MarketFetching.PairMarketData, as: PairMarketData

	# Makes sure private functions are testable.
	@compile if Mix.env == :test, do: :export_all

	def start_link(_arg) do
		Task.start_link(__MODULE__, :poll, [])
	end

	def poll() do
		Stream.interval(10_000)
		|> Stream.map(fn _x -> exchange_market() end)
		|> Enum.each(fn x -> Market.update(x) end)
	end

	defp exchange_market() do
		fetch_market()
		|> filter_valid_pairs()
		|> assemble_exchange_market()
	end

	defp filter_valid_pairs(market) do
		Enum.filter(market, fn {_k, p} ->
			strings = [
				p["symbol"],
				p["tokenAddr"],
			]
			numbers = [
				p["last"],
				p["bid"],
				p["ask"],
				p["baseVolume"],
				p["quoteVolume"]
			]
			Enum.all?(strings, fn s -> valid_string?(s) end)
			Enum.all?(numbers, fn n -> valid_number?(n) end)
		end)
	end

	defp valid_string?(s) do
		cond do
			!is_binary(s) -> false
			s == "" -> false
			true -> true
		end
	end

	defp valid_number?(n) do
		cond do
			!is_number(n) -> false
			n == 0 -> false
			true -> true
		end
	end

	defp assemble_exchange_market(market) do
		eth_address = Util.eth_address()

		complete_market =
			Enum.map(market, fn {_k, p} ->
				%Pair{
					base_symbol: "ETH",
					quote_symbol: p["symbol"],
					base_address: eth_address,
					quote_address: p["tokenAddr"],
					market_data: %PairMarketData{
						exchange: :tokenstore,
						last_price: p["last"],
						current_bid: p["bid"],
						current_ask: p["ask"],
						base_volume: p["baseVolume"],
						quote_volume: p["quoteVolume"],
					}
				}
			end)

		%ExchangeMarket{
			exchange: :tokenstore,
			market: complete_market,
		}
	end

	defp fetch_market() do
		fetch_and_decode("https://v1-1.api.token.store/ticker")
	end

	defp fetch_and_decode(url) do
		case HTTPoison.get!(url) do
			%HTTPoison.Error{} ->
				nil
			%HTTPoison.Response{body: received_body} ->
				case Poison.decode(received_body) do
					{:ok, decoded_market} ->
						decoded_market
					{:error, _message} ->
						nil
				end
		end

	end

end
