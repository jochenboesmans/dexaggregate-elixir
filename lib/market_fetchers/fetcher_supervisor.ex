defmodule FetcherSupervisor do
	@moduledoc false

	use Supervisor

	def start_link(init_arg) do
		Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
	end

	@impl true
	def init(_init_arg) do
		children = [
			{KyberFetcher, [%{}]},
			{IdexFetcher, [%{}]}
		]
		options = [
			strategy: :one_for_one,
			name: __MODULE__,
		]
		Supervisor.init(children, options)
	end
end
