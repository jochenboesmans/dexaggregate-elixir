defmodule Dexaggregatex.Market.Rebasing.Supervisor do
	@moduledoc false
	alias Dexaggregatex.Market.Rebasing.{Cache, Neighbors}
	use Supervisor

	def start_link(init_args) do
		Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
	end

	@impl true
	def init(_args) do
		children = [
			Cache,
			Neighbors
		]
		options = [
			# All children will be restarted if one crashes.
			strategy: :one_for_all,
			name: __MODULE__
		]
		Supervisor.init(children, options)
	end

end
