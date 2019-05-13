defmodule MarketFetching.OasisFetcher do
	@moduledoc """
		Fetches the Oasis market and updates the global Market accordingly.
	"""

	use Task, restart: :permanent

  import MarketFetching.Util

	alias MarketFetching.Pair, as: Pair
	alias MarketFetching.ExchangeMarket, as: ExchangeMarket
	alias MarketFetching.PairMarketData, as: PairMarketData

  @market_endpoint "http://api.oasisdex.com/v1/markets"
  @currencies %{
    "MKR" => "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
    "ETH" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    "DAI" => "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
  }
  @pairs [["MKR", "ETH"], ["MKR", "DAI"], ["ETH", "DAI"]]

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

	def exchange_market() do
		fetch_market()
		|> assemble_exchange_market()
	end

	def assemble_exchange_market(market) do
		c = currencies()

		complete_market =
			Enum.map(market, fn p ->
				[quote_symbol, base_symbol] = String.split(p["pair"], "/")
				%Pair{
					base_symbol: base_symbol,
					quote_symbol: quote_symbol,
					base_address: c[base_symbol],
					quote_address: c[quote_symbol],
					market_data: %PairMarketData{
						exchange: :oasis,
						last_price: transform_rate(p["last"]),
						current_bid: transform_rate(p["bid"]),
						current_ask: transform_rate(p["ask"]),
						base_volume: transform_rate(p["vol"]),
						quote_volume: 0,
					}
				}
			end)

		%ExchangeMarket{
			exchange: :oasis,
			market: complete_market
		}
	end



	def fetch_market() do
		Enum.reduce(pairs(), [], fn ([bs, qs], acc) ->
			case fetch_and_decode("#{@market_endpoint}/#{bs}/#{qs}") do
        {:ok, pair} ->
          [pair | acc]
        {:error, _message} ->
          acc
			end
		end)
	end

	defp transform_rate(rate) do
		cond do
			is_number -> rate
			is_binary(rate) -> try_parse_float(rate)
			true -> 0
		end
	end

  defp try_parse_float(rate) do
    case parse_float(rate) do
      {:ok, valid_float} ->
        valid_float
      {:error, _message} ->
        nil
    end
  end
end
