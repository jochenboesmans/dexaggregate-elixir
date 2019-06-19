defmodule Dexaggregatex.Market.InactivitySweeper do
	@moduledoc """
	Routinely sweeps inactive pairs from the market.
	"""
	use Task

	alias Dexaggregatex.Market.Client, as: MarketClient
	alias Dexaggregatex.Market.Structs.{Market, Pair, ExchangeMarketData}

	@sweep_interval 60_000
	@max_age 3_600_000

	# Make private functions testable.
	@compile if Mix.env == :test, do: :export_all

	@doc """
	Starts an InactivitySweeper process linked to the caller process.
	"""
	@spec start_link(any) :: {:ok, pid}
	def start_link(_arg) do
		Task.start_link(__MODULE__, :sweep, [])
	end

	@doc """
	"""
	@spec sweep() :: any
	def sweep() do
		Stream.interval(@sweep_interval)
		|> Stream.map(fn _x -> MarketClient.market() end)
		|> Enum.each(fn x -> sweep_market(x) end)
	end

	@spec sweep_market(Market.t) :: any
	defp sweep_market(%Market{pairs: pairs}) do
		%{removed_pairs: rp, swept_pairs: sp} =
			Enum.reduce(pairs, %{removed_pairs: [], swept_pairs: %{}},
				fn ({p_id, %Pair{market_data: pmd} = p}, %{removed_pairs: rp, swept_pairs: sp} = pairs_acc) ->
				swept_pmd =
					Enum.reduce(pmd, %{}, fn ({e, %ExchangeMarketData{timestamp: ts} = emd}, acc) ->
						case :os.system_time(:millisecond) - ts < @max_age do
							true -> Map.put(acc, e, emd)
							false -> acc
						end
					end)
				case Enum.count(swept_pmd) do
					0 -> %{pairs_acc | removed_pairs: [p | rp]}
					_ -> %{pairs_acc | swept_pairs: Map.put(sp, p_id, %{p | market_data: swept_pmd})}
				end
			end)
		MarketClient.feed_swept_market(%{removed_pairs: rp, swept_market: %Market{pairs: sp}})
	end
end
