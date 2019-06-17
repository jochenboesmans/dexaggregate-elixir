defmodule Dexaggregatex.Market.Supervisor do
  @moduledoc false
  alias Dexaggregatex.Market.{Server, Rebasing, Neighbors}
  use Supervisor

  def start_link(init_args) do
    Supervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children = [
      Server,
      Rebasing.Cache,
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
