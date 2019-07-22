defmodule Dexaggregatex.MarketFetching.Supervisor do
  @moduledoc """
  Supervisor for all MarketFetcher processes.
  """
  use Supervisor

  alias Dexaggregatex.MarketFetching.{
    DdexFetcher,
    IdexFetcher,
    KyberFetcher,
    OasisFetcher,
    ParadexFetcher,
    RadarFetcher,
    TokenstoreFetcher,
    UniswapFetcher
  }

  @spec start_link(any) :: Supervisor.on_start()
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
      #{TokenstoreFetcher, []},
      {UniswapFetcher, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
