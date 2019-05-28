defmodule Graphql.Socket do
  @moduledoc false

  use Phoenix.Socket
  use Absinthe.Phoenix.Socket,
    schema: Graphql.Schema

  transport :websocket, Phoenix.Transports.WebSocket
end
