defmodule DexAggregate.Application do
	@moduledoc false

	use Application

	def start(_type, _args) do
		children = [
			{Market, name: Market}
		]
		options = [strategy: :one_for_one, name: DexAggregate.Supervisor]
		Supervisor.start_link(children, options)
	end

end
