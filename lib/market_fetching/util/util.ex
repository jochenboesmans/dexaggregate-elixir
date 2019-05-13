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
	def fetch_and_decode(url, args \\ []) do
		case HTTPoison.get(url, args) do
			{:ok, response} ->
				decode(response)
			{:error, message} ->
				{:error, message}
		end
	end

	@doc """
		Issues an empty post request to the specified url and returns the JSON-decoded response.
	"""
	def post_and_decode(url) do
		case HTTPoison.post(url, Poison.encode!(%{})) do
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
			{:ok, decoded_body} ->
				{:ok, decoded_body}
			:error ->
				{:error, "Couldn't decode body of HTTP response."}
		end
	end

	@doc """
		Tries to parse a float from a given value. Returns true only when the value can be purely parsed to a useful float.
	"""
	def valid_float?(float_string) do
		case float_string do
			nil ->
				false
			_ ->
				case Float.parse(float_string) do
					:error -> false
					{0.0, ""} -> false
					{0, ""} -> false
					{_valid, ""} -> true
					_contains_non_numbers -> false
				end
		end
	end

	@doc """
		Parses a float from a given value.
	"""
	def parse_float(float_string) do
		case valid_float?(float_string) do
			true ->
				elem(Float.parse(float_string), 0)
			false ->
				0.0
		end
	end

	def valid_string?(string) do
		case string do
			nil -> false
			"" -> false
			_ -> true
		end
	end

	def valid_values?(expected_strings, expected_numbers) do
		Enum.all?(expected_strings, fn s -> valid_string?(s) end)
		&& Enum.all?(expected_numbers, fn n -> valid_float?(n) end)
	end
end
