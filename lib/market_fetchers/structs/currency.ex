defmodule MarketFetchers.Structs.Currency do
	@moduledoc false

	@enforce_keys [
		:address,
		:symbol
	]

	defstruct(
		address: nil,
		symbol: nil
	)
end
