defmodule Dexaggregatex.API.Socket do
  @moduledoc """
  Control channel for handling GraphQL subscriptions.
  """
  alias Dexaggregatex.API.GraphQL

  use Phoenix.Socket
  use Absinthe.Phoenix.Socket,
    schema: GraphQL.Schema

  @doc false
  def connect(_params, socket) do
    socket = Absinthe.Phoenix.Socket.put_options(socket, [
      context: %{}
    ])
    {:ok, socket}
  end

  @doc false
  def id(_socket), do: nil
end
