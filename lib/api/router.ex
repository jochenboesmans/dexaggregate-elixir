defmodule API.Router do
	@moduledoc """
		A simple router for the application's API.
	"""

	use Plug.Router

	@port 5000

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

	get "/rebased_market" do
		conn
		|> put_resp_content_type("application/json")
		|> send_resp(200, Poison.encode!(Market.get(:rebased_market)))
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
		Plug.Cowboy.http(__MODULE__, [], port: @port)
	end
end
