defmodule Dexaggregatex.Market.Rebasing.Supervisor do
  @moduledoc false
  use Supervisor
  alias Dexaggregatex.Market.Rebasing.{Cache, Neighbors}

  @spec start_link(any) :: Supervisor.on_start()
  def start_link(init_args) do
    Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      Cache,
      Neighbors
    ]

    # All children will be restarted if one crashes.
    Supervisor.init(children, strategy: :one_for_all)
  end
end
