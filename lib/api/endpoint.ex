defmodule Dexaggregatex.API.Endpoint do
	alias Dexaggregatex.API.{Socket, Router}

	use Phoenix.Endpoint, otp_app: :dexaggregatex
	use Absinthe.Phoenix.Endpoint

	socket "/socket", Socket,
 		websocket: true,
		longpoll: false

	# Serve at "/" the static files from "priv/static" directory.
	#
	# You should set gzip to true if you are running phx.digest
	# when deploying your static files in production.
	plug Plug.Static,
		at: "/",
		from: :dexaggregatex,
		gzip: true,
		only: ~w(css fonts images js favicon.ico robots.txt)

	# Code reloading can be explicitly enabled under the
	# :code_reloader configuration of your endpoint.
	if code_reloading? do
		socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
		plug Phoenix.LiveReloader
		plug Phoenix.CodeReloader
	end

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
