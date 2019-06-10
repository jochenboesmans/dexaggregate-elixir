defmodule Dexaggregatex.API.RestController do

	alias Dexaggregatex.Market.Client, as: MarketClient
	alias Dexaggregatex.API

	import API.Format
	use API, :controller

	def get(conn, %{"what_to_get" => what} = _params) do
		result =
			case what do
				"last_market" -> get_last_update()
				"exchanges" -> get_exchanges()
				"dai_rebased_market" -> get_dai_rebased_market()
				"market" -> get_market()
				_ -> %{"error" => "please use a valid route."}
			end
			|> Poison.encode!
		put_json_on_conn(conn, result)
	end

	defp get_market() do
		MarketClient.get(:market)
		|> queryable_market(%{})
	end

	defp get_dai_rebased_market() do
		dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
		MarketClient.get({:rebased_market, dai_address}).pairs
		|> queryable_rebased_market(%{rebase_address: dai_address})
	end

	defp get_exchanges() do
		MarketClient.get(:exchanges)
		|> queryable_exchanges_in_market
	end

	defp get_last_update() do
		MarketClient.get(:last_update)
	end

	defp put_json_on_conn(conn, data) do
		conn
		|> put_resp_content_type("application/json")
		|> send_resp(200, data)
	end
end
