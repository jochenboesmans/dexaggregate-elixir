defmodule Dexaggregatex.Application do
	alias Dexaggregatex.{
		MarketFetching,
		Market,
		API,
	}
	use Application

	def start(_type, _args) do
		children = [
			MarketFetching.Supervisor,
			Market.Supervisor,
			API.Supervisor
		]
		options = [
			# All children will be restarted if one crashes.
			strategy: :one_for_all,
			name: __MODULE__
		]
		Supervisor.start_link(children, options)
	end

end
