defmodule Dexaggregatex.Application do
	use Application
	alias MarketFetching.FetcherSupervisor

	def start(_type, _args) do
		children = [
			{Market, name: Market},
			{FetcherSupervisor, name: FetcherSupervisor},
			{API.Endpoint, name: Endpoint},
			{Absinthe.Subscription, [API.Endpoint]},
			{Rebasing.Cache, name: Rebasing.Cache}
		]
		options = [
			strategy: :one_for_one,
			name: __MODULE__
		]
		Supervisor.start_link(children, options)
	end

	# Tell Phoenix to update the endpoint configuration
	# whenever the application is updated.
	def config_change(changed, _new, removed) do
		API.Endpoint.config_change(changed, removed)
		:ok
	end

end
