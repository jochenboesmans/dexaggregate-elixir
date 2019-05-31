defmodule API.Endpoint do
	use Phoenix.Endpoint, otp_app: :dexaggregatex
	use Absinthe.Phoenix.Endpoint

	socket "/socket", API.Socket,
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

	plug API.Router
end
