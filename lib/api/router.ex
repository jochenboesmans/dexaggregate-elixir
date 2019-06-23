defmodule Dexaggregatex.API.Router do
	@moduledoc """
	Simple router for requests to REST and GraphQL API.
	"""
	alias Dexaggregatex.API
	alias API.{Socket, RestController, GraphQL}

	use API, :router

	get "/", RestController, :root

	scope "/" do
		forward "/graphiql", Absinthe.Plug.GraphiQL,
			schema: GraphQL.Schema,
			socket: Socket

		forward "/graphql", Absinthe.Plug,
			schema: GraphQL.Schema

		get "/:what_to_get", RestController, :get
		get "/:what_to_get/:rebase_address", RestController, :get
	end
end
