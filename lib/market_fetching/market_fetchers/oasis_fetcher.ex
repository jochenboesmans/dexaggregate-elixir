defmodule MarketFetching.OasisFetcher do
	@moduledoc """
		Fetches the Oasis market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent

  import MarketFetching.Util
	alias MarketFetching.{Pair, ExchangeMarket, PairMarketData}

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
		|> Enum.each(fn x -> maybe_update(x) end)
	end

	def exchange_market() do
		c = @currencies

		complete_market =
			Enum.reduce(@pairs, [], fn (p, acc) ->
				case fetch_pair(p) do
					{:ok, pair} ->
						%{
							"pair" => id,
							"last" => lp,
							"bid" => cb,
							"ask" => ca,
							"vol" => bv,
						} = pair
						[qs, bs] = String.split(id, "/")
						[ba, qa] = [c[bs], c[qs]]

						case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
							true ->
								[generic_market_pair([bs, qs, ba, qa, lp, cb, ca, bv], :oasis) | acc]
							false ->
								acc
						end
					{:error, _message} ->
						acc
				end
			end)

		%ExchangeMarket{
			exchange: :oasis,
			market: complete_market
		}
	end

	defp fetch_pair([bs, qs]) do
		case fetch_and_decode("#{@market_endpoint}/#{bs}/#{qs}") do
			{:ok, %{"data" => pair}} ->
				{:ok, pair}
			{:error, _message} ->
				{:error, _message}
		end
	end
end
