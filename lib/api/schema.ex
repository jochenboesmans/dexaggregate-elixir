defmodule API.Schema do
  @moduledoc false

  use Absinthe.Schema

  object :market do
    @desc "Get the whole market"
    field :market, :market do
      resolve(&API.Resolver.get/3)
    end
  end

  query do
    import_fields(:market)
  end
end
