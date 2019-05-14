defmodule Market.Util do
	@moduledoc """
		Generic functions used for maintaining the market model.
	"""

	alias Market.Pair

	@doc """
		Determines the internal id of a Market.Pair.
	"""
	def pair_id(%Pair{base_address: ba, quote_address: qa}) do
		Base.encode64(:crypto.hash(:sha512, "#{ba}/#{qa}"))
	end

	@doc """
		Determines the internal id of a Market.Pair.
	"""
	def pair_id(ba, qa) do
		Base.encode64(:crypto.hash(:sha512, "#{ba}/#{qa}"))
	end
end
