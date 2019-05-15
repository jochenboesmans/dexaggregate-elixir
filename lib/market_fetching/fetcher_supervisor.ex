defmodule MarketFetching.FetcherSupervisor do
	@moduledoc """
		Supervisor for all MarketFetcher modules.
	"""
	use Supervisor

	alias MarketFetching.{DdexFetcher, IdexFetcher, KyberFetcher, OasisFetcher,
		ParadexFetcher, RadarFetcher, TokenstoreFetcher, UniswapFetcher}

	def start_link(init_arg) do
		Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
	end

	@impl true
	def init(_init_arg) do
		children = [
			{DdexFetcher, []},
			{IdexFetcher, []},
			{KyberFetcher, []},
			{OasisFetcher, []},
			{ParadexFetcher, []},
			{RadarFetcher, []},
			{TokenstoreFetcher, []},
			#{UniswapFetcher, []},
		]
		options = [
			strategy: :one_for_one,
			name: __MODULE__,
		]
		Supervisor.init(children, options)
	end
end
