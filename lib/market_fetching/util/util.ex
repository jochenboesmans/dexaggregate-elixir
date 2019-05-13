defmodule MarketFetching.Util do
	@moduledoc """
		Generic functions used for market fetching.
	"""

	@doc """
		Returns an Ethereum address referring to Ether as if it were an Ethereum token.

	## Examples
		iex> MarketFetching.Util.eth_address()
		"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	"""
	def eth_address() do
		"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	end


	@doc """
		Issues a get request to the specified url and returns the JSON-decoded response.
	"""
	def fetch_and_decode(url) do
		case HTTPoison.get(url) do
			{:ok, response} ->
				decode(response)
			{:error, message} ->
				{:error, message}
		end
	end


	@doc """
		Returns the JSON-decoded version of the body of a given HTTPoison response.
	"""
	def decode(%HTTPoison.Response{body: body}) do
		case Poison.decode(body) do
			{:ok, %{"data" => decoded_data}} ->
				{:ok, decoded_data}
			{:error, message}
				{:error, message}
		end
	end
end
