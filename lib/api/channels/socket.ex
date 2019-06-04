defmodule API.Socket do
  use Phoenix.Socket
  use Absinthe.Phoenix.Socket,
    schema: Graphql.Schema

  def connect(_params, socket) do
    socket = Absinthe.Phoenix.Socket.put_options(socket, [
      context: %{}
    ])
    {:ok, socket}
  end

  def id(_socket), do: nil
end
