defmodule TokenstoreFetcher do
	@moduledoc """
	Fetches the Tokenstore market.
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
		m = market()

		complete_market = Enum.map(m, fn p ->
			%Pair{
				base_symbol: p.base_symbol,
				quote_symbol: p.quote_symbol,
				base_address: p.base_address,
				quote_address: p.quote_address,
				market_data: p.market_data
			}
		end)

		%ExchangeMarket{
			exchange: :tokenstore,
			market: complete_market
		}
	end

	defp market() do
		fetch_market()
		|> transform_market()
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

	defp eth_address() do
		"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	end

	def fetch_market() do
		fetch_and_decode("https://v1-1.api.token.store/ticker")
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

		Enum.map(market, fn {p, v} ->
			[_, quote_symbol] = String.split(p, "_")
			%Pair{
				base_symbol: "ETH",
				quote_symbol: quote_symbol,
				base_address: eth_address,
				quote_address: v["tokenAddr"],
				market_data: %PairMarketData{
					last_traded: v["last"],
					current_bid: v["bid"],
					current_ask: v["ask"],
					base_volume: v["baseVolume"],
					quote_volume: v["quoteVolume"],
				}
			}
		end)
	end
end
