defmodule API.Router do
	@moduledoc """
		A simple router for the application's API.
	"""
	use Plug.Router

	plug Plug.Parsers,
		parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
		pass: ["*/*"],
		json_decoder: Poison

	plug :match
	plug :dispatch

	forward "/graphql/regular", to: Absinthe.Plug,
		schema: Graphql.Schema

	forward "/graphql/graphiql", to: Absinthe.Plug.GraphiQL,
    schema: Graphql.Schema

	get "/market" do
		conn
		|> put_resp_content_type("application/json")
		|> send_resp(200, Poison.encode!(Market.get(:market)))
	end

	@dai_address "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
	get "/dai_rebased_market" do
		args = %{
			rebase_address: @dai_address,
			exchanges: [:radar]
		}
		conn
		|> put_resp_content_type("application/json")
		|> send_resp(200, Poison.encode!(Market.get({:rebased_market, args})))
	end

	get "/exchanges" do
		conn
		|> put_resp_content_type("application/json")
		|> send_resp(200, Poison.encode!(Market.get(:exchanges)))
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
end
