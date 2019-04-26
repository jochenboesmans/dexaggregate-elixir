defmodule Util do
	@moduledoc false

	alias MarketFetching.Pair, as: Pair

	def pair_id(%Pair{base_address: ba, quote_address: qa}) do
		Base.encode64(:crypto.hash(:sha512, "#{ba}/#{qa}"))
	end
	def pair_id(ba, qa) do
		Base.encode64(:crypto.hash(:sha512, "#{ba}/#{qa}"))
	end
end
