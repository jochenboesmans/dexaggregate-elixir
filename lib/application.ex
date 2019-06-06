defmodule Dexaggregatex.Application do
	alias Dexaggregatex.{
		Market,
		MarketFetching.FetcherSupervisor,
		API.Endpoint,
		Market.Rebasing
	}
	use Application

	def start(_type, _args) do
		children = [
			Market,
			FetcherSupervisor,
			Endpoint,
			{Absinthe.Subscription, [Endpoint]},
			Rebasing.Cache
		]
		options = [
			# All children will be restarted if one crashes.
			strategy: :one_for_all,
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
