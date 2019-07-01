defmodule Dexaggregatex.API.Socket do
  @moduledoc """
  Control channel for handling GraphQL subscriptions.
  """
  alias Dexaggregatex.API.GraphQL

  use Phoenix.Socket

  use Absinthe.Phoenix.Socket,
    schema: GraphQL.Schema

  @spec connect(map, Phoenix.Socket.t()) :: {:ok, Phoenix.Socket.t()}
  def connect(_params, socket) do
    socket =
      Absinthe.Phoenix.Socket.put_options(socket,
        context: %{}
      )

    {:ok, socket}
  end

  @spec id(Phoenix.Socket.t()) :: nil
  def id(_socket), do: nil
end
