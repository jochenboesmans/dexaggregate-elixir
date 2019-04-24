defmodule MarketFetchers.FetcherSupervisor do
	@moduledoc false

	use Supervisor
	alias MarketFetchers.DdexFetcher, as: DdexFetcher
	alias MarketFetchers.IdexFetcher, as: IdexFetcher
	alias MarketFetchers.KyberFetcher, as: KyberFetcher
	alias MarketFetchers.OasisFetcher, as: OasisFetcher
	alias MarketFetchers.ParadexFetcher, as: ParadexFetcher
	alias MarketFetchers.RadarFetcher, as: RadarFetcher
	alias MarketFetchers.TokenstoreFetcher, as: TokenstoreFetcher
	alias MarketFetchers.UniswapFetcher, as: UniswapFetcher

	def start_link(init_arg) do
		Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
	end

	@impl true
	def init(_init_arg) do
		children = [
			#{DdexFetcher, []},
			{IdexFetcher, []},
			{KyberFetcher, []},
			{OasisFetcher, []},
			#{ParadexFetcher, []},
			{RadarFetcher, []},
			{TokenstoreFetcher, []},
			{UniswapFetcher, []},
		]
		options = [
			strategy: :one_for_one,
			name: __MODULE__,
		]
		Supervisor.init(children, options)
	end
end
