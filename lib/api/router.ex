defmodule API.Router do
	use API, :router

	pipeline :api do
		plug :accepts, ["json"]
	end

	scope "/" do
		pipe_through :api

		if Mix.env == :dev do
			forward "/graphiql", Absinthe.Plug.GraphiQL,
				schema: Graphql.Schema,
				socket: API.Socket
		end

		forward "/graphql", Absinthe.Plug,
			schema: Graphql.Schema

		get "/:what_to_get", API.RestController, :get
	end
end
