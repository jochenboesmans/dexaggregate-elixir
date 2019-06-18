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
	@spec eth_address() :: String.t
	def eth_address() do
		"0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
	end

	@doc """
	Issues a get request to the specified url and returns the JSON-decoded response.
	"""
	@spec fetch_and_decode(String.t, [tuple]) :: :error | {:ok, Poison.Parser.t}
	def fetch_and_decode(url, headers \\ []) do
		case HTTPoison.get(url, headers) do
			{:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
				Poison.decode(body)
			{:ok, _} ->
				:error
			{:error, _} ->
				:error
		end
	end

	@doc """
	Issues an empty post request to the specified url and returns the JSON-decoded response.
	"""
	@spec post_and_decode(String.t) :: :error | {:ok, Poison.Parser.t}
	def post_and_decode(url) do
		case HTTPoison.post(url, Poison.encode!(%{})) do
			{:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
				Poison.decode(body)
			{:ok, _} ->
				:error
			{:error, _} ->
				:error
		end
	end

	@doc """
	Tries to parse a float from a given value.
	Returns true only when the value can be purely parsed to a useful float.

	## Examples
		iex> Dexaggregatex.MarketFetching.Util.valid_float?("1.1")
		true

		iex> Dexaggregatex.MarketFetching.Util.valid_float?(0.0)
		false
	"""
	@spec valid_float?(any) :: boolean
	def valid_float?(float_string) do
		cond do
			!is_binary(float_string) && !is_number(float_string)
			|| float_string == 0 || float_string == "" || float_string == "N/A" ->
				false
			is_number(float_string) ->
				true
			true ->
				case Float.parse(float_string) do
					:error -> false
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
	@spec parse_float(any) :: float
	def parse_float(float_string) do
		case is_number(float_string) do
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
end
