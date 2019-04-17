defmodule FetcherSupervisor do
	@moduledoc false

	use Supervisor

	def start_link(_init_arg) do
		children = [
			{IdexFetcher, [%{}]},
			{KyberFetcher, [%{}]},
		]
		options = [
			strategy: :one_for_one,
			name: __MODULE__,
    ]
		Supervisor.start_link(children, options)
	end
end
