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
	@poll_interval 10_000

  # Makes sure private functions are testable.
  @compile if Mix.env == :test, do: :export_all

	def start_link(_arg) do
		Task.start_link(__MODULE__, :poll, [])
	end

	def poll() do
		Stream.interval(@poll_interval)
		|> Stream.map(fn _x -> exchange_market() end)
		|> Enum.each(fn x -> Market.update(x) end)
	end

	def exchange_market() do
		fetch_market()
		|> assemble_exchange_market()
	end

	def try_get_valid_pair(p, c) do
		%{
			"pair" => id,
			"last" => lp,
			"bid" => cb,
			"ask" => ca,
			"vol" => bv,
		} = p
		[qs, bs] = String.split(id, "/")
		[ba, qa] = [c[bs], c[qs]]

		case valid_values?([bs, qs, ba, qa], [bv, lp, cb, ca]) do
			true ->
				%Pair{
					base_symbol: bs,
					quote_symbol: qs,
					base_address: c[bs],
					quote_address: c[qs],
					market_data: %PairMarketData{
						exchange: :oasis,
						last_price: parse_float(lp),
						current_bid: parse_float(cb),
						current_ask: parse_float(ca),
						base_volume: parse_float(bv),
					}
				}
			false ->
				nil
		end
	end

	def assemble_exchange_market(market) do
		c = @currencies

		complete_market =
			Enum.reduce(market, [], fn (p, acc) ->
				case try_get_valid_pair(p, c) do
					nil ->
						acc
					valid_pair ->
						[valid_pair | acc]
				end
			end)

		%ExchangeMarket{
			exchange: :oasis,
			market: complete_market
		}
	end

	def fetch_market() do
		Enum.reduce(@pairs, [], fn ([bs, qs], acc) ->
			case fetch_and_decode("#{@market_endpoint}/#{bs}/#{qs}") do
        {:ok, pair} ->
          [pair | acc]
        {:error, _message} ->
          acc
			end
		end)
	end
end
