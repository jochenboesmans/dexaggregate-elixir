defmodule Dexaggregatex.API.Router do
	alias Dexaggregatex.API
	alias API.{Socket, RestController, GraphQL}

	use API, :router

	pipeline :api do
		plug :accepts, ["json"]
	end

	scope "/" do
		pipe_through :api

		if Mix.env == :dev do
			forward "/graphiql", Absinthe.Plug.GraphiQL,
				schema: GraphQL.Schema,
				socket: Socket
		end

		forward "/graphql", Absinthe.Plug,
			schema: GraphQL.Schema

		get "/:what_to_get", RestController, :get
	end
end
