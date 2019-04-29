defmodule API.Resolver do
  @moduledoc false

  def get(_parent, _args, _resolutions) do
    {:ok, Market.get()}
  end
end
