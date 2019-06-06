defmodule Dexaggregatex.API.Socket do
  alias Dexaggregatex.API.GraphQL

  use Phoenix.Socket
  use Absinthe.Phoenix.Socket,
    schema: GraphQL.Schema

  def connect(_params, socket) do
    socket = Absinthe.Phoenix.Socket.put_options(socket, [
      context: %{}
    ])
    {:ok, socket}
  end

  def id(_socket), do: nil
end
