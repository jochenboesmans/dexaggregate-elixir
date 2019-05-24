defmodule MarketFetching.Util do
	@moduledoc """
		Generic functions used for market fetching.
	"""
	alias MarketFetching.{Pair, ExchangeMarket, PairMarketData}

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
			#{:ok, {:error, message}} ->
				#{:error, message}
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
			{:error, message} ->
				{:error, message}
		end
	end

	@doc """
		Tries to parse a float from a given value. Returns true only when the value can be purely parsed to a useful float.

	## Examples
		iex> MarketFetching.Util.valid_float?("1.1")
		true
	"""
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
		iex> MarketFetching.Util.parse_float("1.1")
		1.1
	"""
	def parse_float(float_string) do
		case is_float(float_string) || is_integer(float_string) do
			true ->
				float_string
			false ->
				case valid_float?(float_string) do
					true ->
						elem(Float.parse(float_string), 0)
					false ->
						0.0
				end
		end
	end

	def safe_power(number, power) do
		case number == 0 do
			true ->
				number
			false ->
				:math.pow(number, power)
		end
	end


	@doc """
		Determines whether a given string has a valid value to be included in the market.

	## Examples
		iex> MarketFetching.Util.valid_string?("ETH")
		true
	"""
	def valid_string?(string) do
		case string do
			nil -> false
			"" -> false
			_ -> true
		end
	end

	@doc """
		Determines whether all given values have a valid value to be included in the market.
	"""
	def valid_values?(strings: exp_strings, numbers: exp_numbers) do
		Enum.all?(exp_strings, fn s -> valid_string?(s) end)
		&& Enum.all?(exp_numbers, fn n -> valid_float?(n) end)
	end

	@doc """
		Formats given pair data in a well-formed PairMarketData structure.
	"""
	def generic_market_pair([bs, qs, ba, qa, lp, cb, ca, bv], exchange) do
		%Pair{
			base_symbol: bs,
			quote_symbol: qs,
			base_address: ba,
			quote_address: qa,
			market_data: %PairMarketData{
				exchange: exchange,
				last_price: parse_float(lp),
				current_bid: parse_float(cb),
				current_ask: parse_float(ca),
				base_volume: parse_float(bv),
			}
		}
	end

	@doc """
		Updates the global market with the given exchange market if it holds valid pairs.
	"""
	def maybe_update(%ExchangeMarket{market: complete_market} = x) do
		case complete_market do
			nil ->
				nil
			[] ->
				nil
			_ ->
				Market.update(x)
		end
	end
end
