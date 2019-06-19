defmodule Dexaggregatex.Market.Supervisor do
  @moduledoc false
  alias Dexaggregatex.Market.{Server, InactivitySweeper, Rebasing}
  use Supervisor

  def start_link(init_args) do
    Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      Server,
      InactivitySweeper,
      Rebasing.Supervisor
    ]
    # All children will be restarted if one crashes.
    Supervisor.init(children, strategy: :one_for_all)
  end
end
