defmodule MarketFetching.ParadexFetcher do
	@moduledoc """
		Fetches the Paradex market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent

  import MarketFetching.Util

	alias MarketFetching.Pair, as: Pair
	alias MarketFetching.ExchangeMarket, as: ExchangeMarket
	alias MarketFetching.PairMarketData, as: PairMarketData

  @base_api_url "https://api.paradex.io/api/v1"
  @currencies_endpoint "/tokens"
  @market_endpoint "/markets"
  @ohlcv_endpoint "/ohlcv"
  @ticker_endpoint "/ticker"

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
		|> assemble_exchange_market()
	end

	defp assemble_exchange_market(market) do
		c = currencies()

		complete_market =
			Enum.reduce(market, [], fn (p, acc) ->
				%{"baseToken" => bs,
					"quoteToken" => qs,
					"symbol" => market_symbol
				} = p
				bv =
					case fetch_ohlcv(market_symbol) do
						%{"error" => _} -> nil
						[%{"volume" => vol}] -> vol
					end
				[lp, cb, ca] =
					case fetch_ticker(market_symbol) do
						%{"error" => _} -> [nil, nil, nil]
						[%{"lastPrice" => last, "bestBid" => bid, "bestAsk" => ask}] -> [last, bid, ask]
					end
				%{^bs => ba, ^qs => qa} = c

				exp_strings = [bs, qs, ba, qa]
				exp_numbers = [bv, lp, cb, ca] = [parse_float(bv), parse_float(lp), parse_float(cb), parse_float(ca)]

				case Enum.all?(exp_strings, fn s -> valid_string?(s) end)
					&& Enum.all?(exp_numbers, fn n -> valid_number?(n) end) do
					false ->
						acc
					true ->
						market_pair = %Pair{
							base_symbol: bs,
							quote_symbol: qs,
							base_address: ba,
							quote_address: qa,
							market_data: %PairMarketData{
								exchange: :paradex,
								last_price: lp,
								current_bid: cb,
								current_ask: ca,
								base_volume: bv,
								quote_volume: 0,
							}
						}
						[market_pair | acc]
				end
			end)

		%ExchangeMarket{
			exchange: :paradex,
			market: complete_market
		}
	end

	defp parse_float(s) do
		case s do
			nil ->
				nil
			_ ->
				case Float.parse(s) do
					:error -> 0
					{float, _string_part} -> float
				end
		end

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

	defp currencies() do
		fetch_currencies()
		|> Enum.reduce(%{}, fn (c, acc) -> Map.put(acc, c["symbol"], c["address"]) end)
	end

	defp fetch_currencies() do fetch_and_decode_with_api_key("#{@base_api_url}/#{@currencies_endpoint}") end
	defp fetch_market() do fetch_and_decode_with_api_key("#{@base_api_url}/#{@market_endpoint}") end
	defp fetch_ohlcv(symbol) do fetch_and_decode_with_api_key("#{@base_api_url}/#{@ohlcv_endpoint}?market=#{symbol}&period=1d&amount=1") end
	defp fetch_ticker(symbol) do fetch_and_decode_with_api_key("#{@base_api_url}/#{@ticker_endpoint}?market=#{symbol}") end

	defp fetch_and_decode_with_api_key(url) do
		fetch_and_decode(url, [{"API-KEY", api_key()}]) do
	end

	defp api_key() do
		case Application.get_env(:dexaggregate_elixir, __MODULE__, :api_key) do
			[api_key: key] ->
				key
			_ ->
				nil
		end
	end
end
