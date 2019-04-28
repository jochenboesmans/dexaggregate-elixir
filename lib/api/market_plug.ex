defmodule MarketPlug do
	@moduledoc false

	import Plug.Conn

	def init(options), do: options

	def call(conn, _opts) do
		conn
		|> put_resp_content_type("application/json")
		|> send_resp(200, Poison.decode!(%{"Ello" => "mate"}))
	end

end
