defmodule Dexaggregatex.Application do
	use Application
	alias Dexaggregatex.{
		Market,
		MarketFetching.FetcherSupervisor,
		API.Endpoint,
		Market.Rebasing
	}


	def start(_type, _args) do
		children = [
			{Market, name: Market},
			{FetcherSupervisor, name: FetcherSupervisor},
			{Endpoint, name: Endpoint},
			{Absinthe.Subscription, [Endpoint]},
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
		Endpoint.config_change(changed, removed)
		:ok
	end

end
