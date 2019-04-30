defmodule API.Resolver do
  @moduledoc false

  def get_market(_parent, _args, _resolutions) do
    {:ok, Market.get()}
  end
end
