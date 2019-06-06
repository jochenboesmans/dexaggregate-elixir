defmodule Dexaggregatex.MarketFetching.Util do
	@moduledoc """
		Utility functions used for market fetching.
	"""

	@doc """
		Returns an Ethereum address referring to Ether as if it were an Ethereum token.

	## Examples
		iex> Dexaggregatex.MarketFetching.Util.eth_address()
		"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	"""
	@spec eth_address() :: String.t()
	def eth_address() do
		"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	end

	@doc """
		Issues a get request to the specified url and returns the JSON-decoded response.
	"""
	@spec fetch_and_decode(String.t(), [tuple()])
				:: {:error, String.t()} | {:ok, any()}
	def fetch_and_decode(url, headers \\ []) do
		case HTTPoison.get(url, headers) do
			{:ok, response} ->
				decode(response)
			{:error, message} ->
				{:error, message}
		end
	end

	@doc """
		Issues an empty post request to the specified url and returns the JSON-decoded response.
	"""
	@spec post_and_decode(String.t())
				:: {:error, String.t()} | {:ok, any()}
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
	@spec decode(HTTPoison.Response.t())
				:: {:error, String.t()} | {:ok, any()}
	def decode(%HTTPoison.Response{body: body}) do
		case Poison.decode(body) do
			{:ok, decoded_body} ->
				{:ok, decoded_body}
			{:error, message} ->
				{:error, message}
		end
	end

	@doc """
		Tries to parse a float from a given value. Returns true only when the value can be purely parsed to a useful float.

	## Examples
		iex> Dexaggregatex.MarketFetching.Util.valid_float?("1.1")
		true
	"""
	@spec valid_float?(any()) :: boolean()
	def valid_float?(float_string) do
		cond do
			float_string == nil ->
				false
			is_float(float_string) || is_integer(float_string) ->
				true
			true ->
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
		Parses a pure float from a given value.

	## Examples
		iex> Dexaggregatex.MarketFetching.Util.parse_float("1.1")
		1.1
	"""
	@spec parse_float(any()) :: float()
	def parse_float(float_string) do
		case is_float(float_string) || is_integer(float_string) do
			true ->
				case is_float(float_string) do
					true -> float_string
					false -> float_string / 1
				end
			false ->
				case valid_float?(float_string) do
					true ->
						elem(Float.parse(float_string), 0)
					false ->
						0.0
				end
		end
	end

	@doc """
	Safely raises a number to a power.

	## Examples
		iex> Dexaggregatex.MarketFetching.Util.safe_power(0, 0)
		1

		iex> Dexaggregatex.MarketFetching.Util.safe_power(0, -1)
		0

		iex> Dexaggregatex.MarketFetching.Util.safe_power(2, -1)
		0.5
	"""
	@spec safe_power(number(), number()) :: number()
	def safe_power(number, power) do
		case number == 0 do
			true ->
				case power == 0 do
					true -> 1
					false -> number
				end
			false ->
				:math.pow(number, power)
		end
	end

end
