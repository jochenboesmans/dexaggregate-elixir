defmodule Dexaggregatex.Util do
	@moduledoc """
	General utility functions.
	"""

	@doc """
	Safely raises a number to a power.

	## Examples
		iex> Dexaggregatex.Util.safe_power(0, 0)
		1

		iex> Dexaggregatex.Util.safe_power(0, -1)
		0

		iex> Dexaggregatex.Util.safe_power(2, -1)
		0.5
	"""
	@spec safe_power(number, number) :: number
	def safe_power(number, power) do
		case number == 0 do
			true ->
				case power == 0 do
					true -> 1
					false -> number
				end
			false -> :math.pow(number, power)
		end
	end

	@doc """
	Safely divides a dividend by a divisor.

	## Examples
		iex> Dexaggregatex.Util.safe_div(5, 0)
		0

		iex> Dexaggregatex.Util.safe_div(0, 2)
		0

		iex> Dexaggregatex.Util.safe_div(2, 4)
		0.5
	"""
	@spec safe_div(number, number) :: number
	def safe_div(dividend, divisor) do
		case divisor == 0 do
			true -> 0
			false -> dividend / divisor
		end
	end

	@doc """
	Calculates the average of weighted values based on the total.

	## Examples
		iex> Dexaggregatex.Util.weighted_average(%{v1: 2, v2: 10}, 20)
		0.6
	"""
	@spec weighted_average(map, number) :: number
	def weighted_average(weighted_values, total) do
		Enum.reduce(weighted_values, 0, fn ({_key, v}, acc) -> acc + safe_div(v, total) end)
		|> safe_div(Enum.count(weighted_values))
	end
end
