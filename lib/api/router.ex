defmodule API.Router do
	@moduledoc """
		A simple router for the application's API.
	"""
	use Plug.Router

	import API.Format

	plug Plug.Parsers,
		parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
		pass: ["*/*"],
		json_decoder: Poison

	plug :match
	plug :dispatch

	forward "/graphql",
		to: Absinthe.Plug,
		schema: Graphql.Schema

	forward "/graphiql",
		to: Absinthe.Plug.GraphiQL,
		schema: Graphql.Schema

	get "/market" do
		result =
			Market.get(:market)
			|> queryable_market(%{})
			|> Poison.encode!

		put_json_on_conn(conn, result)
	end

	@dai_address "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
	get "/dai_rebased_market" do
		result =
			Market.get({:rebased_market, @dai_address}).pairs
			|> queryable_rebased_market(%{rebase_address: @dai_address})
			|> Poison.encode!

		put_json_on_conn(conn, result)
	end

	get "/exchanges" do
		result =
			Market.get(:exchanges)
			|> queryable_exchanges_in_market
			|> Poison.encode!

		put_json_on_conn(conn, result)
	end

	get "/last_update" do
		result =
			Market.get(:last_update)
			|> Poison.encode!
	end

	match _ do
		send_resp(conn, 404, "Requested page was not found.")
	end

	def child_spec(opts) do
		%{
			id: __MODULE__,
			start: {__MODULE__, :start_link, [opts]},
		}
	end

	def start_link(_arg) do
		[port: port] = Application.get_env(:dexaggregate_elixir, __MODULE__, :port)
		Plug.Cowboy.http(__MODULE__, [], port: port)
	end

	defp put_json_on_conn(conn, data) do
		conn
		|> put_resp_content_type("application/json")
		|> send_resp(200, data)
	end
end
