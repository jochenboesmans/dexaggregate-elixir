defmodule OasisFetcher do

	@moduledoc """
	Fetches the Oasis market.
	"""
	use Task, restart: :permanent

	def start_link(_arg) do
		Task.start_link(__MODULE__, :poll, [])
	end

	def poll() do
		Stream.interval(10_000)
		|> Stream.map(fn _x -> complete_market() end)
		|> Enum.each(fn x -> Market.update(x) end)
	end

	defp complete_market() do
		m = market()
		c = currencies()

		complete_market = Enum.map(m, fn p ->
			%Pair{
				base_symbol: p.base_symbol,
				quote_symbol: p.quote_symbol,
				base_address: c[p.base_symbol],
				quote_address: c[p.quote_symbol],
				market_data: p.market_data
			}
		end)

		%ExchangeMarket{
			exchange: :oasis,
			market: complete_market
		}
	end

	defp market() do
		fetch_market()
		|> transform_market()
	end

	defp currencies() do
		%{
			"MKR" => "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
			"ETH" => "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
			"DAI" => "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
		}
	end

	def fetch_market() do
		currencies = currencies()

		market = for {ci, _vi} <- currencies, {cj, _vj} <- currencies do
			unless ci == cj do
				pair = fetch_and_decode("http://api.oasisdex.com/v1/markets/#{ci}/#{cj}")
				unless pair == %{} do
					pair
				end
			end
		end
		Enum.filter(market, & !is_nil(&1))
	end

	defp fetch_and_decode(url) do
		%HTTPoison.Response{body: received_body} = HTTPoison.get!(url)

		case Poison.decode(received_body) do
			{:ok, %{"data" => decoded_market}} ->
				decoded_market
			{:error, message} ->
				nil
		end
	end

	defp transform_market(market) do
		Enum.map(market, fn p ->
			[base_symbol, quote_symbol] = String.split(p["pair"], "/")
			%Pair{
				base_symbol: base_symbol,
				quote_symbol: quote_symbol,
				base_address: "",
				quote_address: "",
				market_data: %PairMarketData{
					last_traded: transform_rate(p["last"]),
					current_bid: transform_rate(p["bid"]),
					current_ask: transform_rate(p["ask"]),
					base_volume: transform_rate(p["vol"]),
					quote_volume: nil,
				}
			}
		end)
	end

	defp transform_rate(rate) do
		:math.pow(elem(Float.parse(rate), 0), -1)
	end
end
