defmodule MarketFetching.UniswapFetcher do
	@moduledoc """
		Fetches the Uniswap market and updates the global Market accordingly.
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
		|> assemble_exchange_market()
	end

	defp assemble_exchange_market(market) do
		c = currencies()
		eth_address = Util.eth_address()

		complete_market =
			Enum.map(market, fn {t, v} ->
				%Pair{
					base_symbol: "ETH",
					quote_symbol: t,
					base_address: eth_address,
					quote_address: c[t],
					market_data: %PairMarketData{
						exchange: :uniswap,
						last_traded: 1 / v["lastTradePrice"],
						current_bid: 1 / v["price"],
						current_ask: 1 / v["price"],
						base_volume: transform_volume(v["tradeVolume"]),
						quote_volume: transform_volume(v["tradeVolume"]) * v["weightedAvgPrice"],
					}
				}
			end)

		%ExchangeMarket{
			exchange: :uniswap,
			market: complete_market
		}
	end

	defp currencies() do
		%{
			"BAT" => "0x0d8775f648430679a709e98d2b0cb6250d2887ef",
			"DAI" => "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
			"MKR" => "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
			"SPANK" => "0x42d6622dece394b54999fbd73d108123806f6a18",
			"ZRX" => "0xe41d2489571d322189246dafa5ebde1f4699f498",
		}
	end

	defp exchange_addresses() do
		%{
			"BAT" => "0x2E642b8D59B45a1D8c5aEf716A84FF44ea665914",
			"DAI" => "0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14",
			"MKR" => "0x2C4Bd064b998838076fa341A83d007FC2FA50957",
			"SPANK" => "0x4e395304655F0796bc3bc63709DB72173b9DdF98",
			"ZRX" => "0xaE76c84C9262Cdb9abc0C2c8888e62Db8E22A0bF",
		}
	end

	defp fetch_market() do
		Enum.map(exchange_addresses(), fn {t, ea} ->
			{t, fetch_and_decode("https://uniswap-analytics.appspot.com/api/v1/ticker?exchangeAddress=#{ea}")}
		end)
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

	defp transform_volume(vol) do
		String.to_integer(vol) * :math.pow(10, -18)
	end
end
