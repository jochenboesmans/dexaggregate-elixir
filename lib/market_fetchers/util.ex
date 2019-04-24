defmodule MarketFetchers.Util do
	@moduledoc """
		Generic functions used by Fetcher modules.
	"""
	@doc """
		Returns an Ethereum address referring to Ether as if it were an Ethereum token.

	## Examples
		iex> MarketFetchers.Util.eth_address()
		"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	"""
	def eth_address() do
		"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	end
end
