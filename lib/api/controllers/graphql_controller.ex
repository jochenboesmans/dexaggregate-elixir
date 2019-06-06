defmodule Dexaggregatex.API.GraphqlController do
	alias Dexaggregatex.API

	use API, :controller
	use Absinthe.Phoenix.Controller, schema: API.GraphQL.Schema

	# maybe not necessary due to forwarding directly to Absinthe plugs.
end
