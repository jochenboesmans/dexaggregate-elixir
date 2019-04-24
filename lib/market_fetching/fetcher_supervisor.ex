defmodule MarketFetching.FetcherSupervisor do
	@moduledoc """
		Supervisor for all MarketFetcher modules.
	"""

	use Supervisor
	alias MarketFetching.MarketFetchers.DdexFetcher, as: DdexFetcher
	alias MarketFetching.MarketFetchers.IdexFetcher, as: IdexFetcher
	alias MarketFetching.MarketFetchers.KyberFetcher, as: KyberFetcher
	alias MarketFetching.MarketFetchers.OasisFetcher, as: OasisFetcher
	alias MarketFetching.MarketFetchers.ParadexFetcher, as: ParadexFetcher
	alias MarketFetching.MarketFetchers.RadarFetcher, as: RadarFetcher
	alias MarketFetching.MarketFetchers.TokenstoreFetcher, as: TokenstoreFetcher
	alias MarketFetching.MarketFetchers.UniswapFetcher, as: UniswapFetcher

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
