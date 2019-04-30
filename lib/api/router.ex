defmodule API.Router do
	@moduledoc false

	use Plug.Router

	plug :match
	plug :dispatch
	plug Absinthe.Plug, schema: API.Schema

	get "/market" do
		query = """
		query GetMarket() {}
		"""
		market = Absinthe.run(query, API.Schema)

		conn
		|> put_resp_content_type("application/json")
		|> send_resp(200, market)
	end

	match _ do
		send_resp(conn, 404, "Requested page not found.")
	end

	def child_spec(opts) do
		%{
			id: __MODULE__,
			start: {__MODULE__, :start_link, [opts]},
		}
	end

	def start_link(_arg) do
		Plug.Cowboy.http(__MODULE__, [], port: 5000)
	end
end
