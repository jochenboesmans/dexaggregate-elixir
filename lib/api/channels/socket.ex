defmodule API.Socket do
  use Phoenix.Socket
  use Absinthe.Phoenix.Socket,
    schema: Graphql.Schema

  def id(_socket), do: nil
end
