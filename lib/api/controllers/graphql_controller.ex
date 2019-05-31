defmodule API.GraphqlController do
	use API, :controller
	use Absinthe.Phoenix.Controller, schema: Graphql.Schema

	# maybe not necessary due to forwarding directly to Absinthe plugs.
end
