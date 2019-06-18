defmodule Dexaggregatex.API.RestController do
	@moduledoc false
	alias Dexaggregatex.Market.Client, as: MarketClient
	alias Dexaggregatex.API

	import API.Format
	use API, :controller

	def get(conn, %{"what_to_get" => what} = params) do
		case what do
			"last_update" -> successful_fetch(conn, :last_update)
			"exchanges" -> successful_fetch(conn, :exchanges)
			"rebased_market" -> successful_fetch(conn, :rebased_market, params)
			"market" -> successful_fetch(conn, :market)
			_ -> unsuccessful_fetch(conn)
		end
	end

	defp unsuccessful_fetch(conn) do
		send_resp(conn, 404, "Please use a valid route.")
	end

	defp successful_fetch(conn, top_param, params \\ nil) do
		data =
			case top_param do
				:last_update -> get_last_update()
				:exchanges -> get_exchanges()
				:rebased_market ->
					%{"rebase_address" => ra} = params
					get_rebased_market(ra)
				:market -> get_market()
			end
			|> Poison.encode!

		conn
		|> put_resp_content_type("application/json")
		|> send_resp(200, data)
	end

	defp get_market() do
		MarketClient.market() |> format_market()
	end

	defp get_rebased_market(rebase_address) do
		MarketClient.rebased_market(rebase_address) |> format_rebased_market()
	end

	defp get_exchanges() do
		MarketClient.exchanges_in_market()
		|> format_exchanges_in_market()
	end

	defp get_last_update() do
		MarketClient.last_update()
		|> format_last_update()
	end
end
