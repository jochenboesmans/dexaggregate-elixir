defmodule DexAggregate.Application do
	@moduledoc false

	use Application

	alias MarketFetching.FetcherSupervisor

	def start(_type, _args) do
		children = [
			{Market, name: Market},
			{FetcherSupervisor, name: FetcherSupervisor},
			{API.Router, name: API.Router},
			{RebasedMarketCache, name: RebasedMarketCache}
		]
		options = [
			strategy: :one_for_one,
			name: __MODULE__
		]
		Supervisor.start_link(children, options)
	end

end
