defmodule Dexaggregatex.API.Endpoint do
	alias Dexaggregatex.API.{Socket, Router}

	use Phoenix.Endpoint, otp_app: :dexaggregatex
	use Absinthe.Phoenix.Endpoint

	socket "/socket", Socket,
 		websocket: true,
		longpoll: false

	plug Plug.RequestId
	plug Plug.Logger

	plug Plug.Parsers,
		parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
		pass: ["*/*"],
		json_decoder: Phoenix.json_library()

	plug Plug.MethodOverride
	plug Plug.Head

	plug Router
end
