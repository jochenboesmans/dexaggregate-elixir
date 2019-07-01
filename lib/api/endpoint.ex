defmodule Dexaggregatex.API.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :dexaggregatex
  use Absinthe.Phoenix.Endpoint

  alias Dexaggregatex.API.{Socket, Router}

  plug CORSPlug, origin: "*"

  socket "/socket", Socket,
    websocket: true,
    longpoll: false

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
