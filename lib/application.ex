defmodule DexAggregate.Application do
	@moduledoc false

	use Application

	def start(_type, _args) do
		children = [
			{Market, name: Market},
			{FetcherSupervisor, name: FetcherSupervisor},
			{Router, name: Router},
		]
		options = [
			strategy: :one_for_one,
			name: __MODULE__
		]
		Supervisor.start_link(children, options)
	end

end
