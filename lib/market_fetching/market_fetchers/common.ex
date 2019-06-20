defmodule Dexaggregatex.MarketFetching.Common do
	@moduledoc """
	Generic functions used for market fetching.
	"""
	alias Dexaggregatex.MarketFetching.Structs.{Pair, ExchangeMarket, PairMarketData}
	alias Dexaggregatex.Market

	import Dexaggregatex.MarketFetching.Util

	@doc """
	Determines whether a given variable has a valid value to be included in the market as a string.

	## Examples
		iex> Dexaggregatex.MarketFetching.Common.valid_string?("ETH")
		true

		iex> Dexaggregatex.MarketFetching.Common.valid_string?("0x548")
		true

		iex> Dexaggregatex.MarketFetching.Common.valid_string?("")
		false

		iex> Dexaggregatex.MarketFetching.Common.valid_string?("N/A")
		false
	"""
	@spec valid_string?(any) :: boolean
	def valid_string?(value) do
		case is_binary(value) do
			true ->
				case value do
					"" -> false
					"N/A" -> false
					_ -> true
				end
			false ->
				false
		end
	end

	@doc """
	Determines whether all given values have a valid value to be included in the market.

	## Examples
		iex> Dexaggregatex.MarketFetching.Common.valid_values?(strings: ["", nil, "bla", "bla"], numbers: [1, 2, 3, 4])
		false

		iex> Dexaggregatex.MarketFetching.Common.valid_values?(strings: ["ETH", "0x548"], numbers: [1.1, "5.6"])
		true
	"""
	@spec valid_values?(strings: [String.t], numbers: [number]) :: boolean
	def valid_values?(strings: exp_strings, numbers: exp_numbers) do
		Enum.all?(exp_strings, fn s -> valid_string?(s) end)
		&& Enum.all?(exp_numbers, fn n -> valid_float?(n) end)
	end

	@doc """
	Formats pair data in a well-formed PairMarketData structure.

	## Examples
		iex> Dexaggregatex.MarketFetching.Common.generic_market_pair(
		iex>  strings: ["ETH", "DAI", "0x123", "0x456"], numbers: [1, 2, 3, 4], exchange: :uniswap)
		%Dexaggregatex.MarketFetching.Structs.Pair{
			base_symbol: "ETH",
			quote_symbol: "DAI",
			base_address: "0x123",
			quote_address: "0x456",
			market_data: %Dexaggregatex.MarketFetching.Structs.PairMarketData{
				exchange: :uniswap,
				last_price: 1.0,
				current_bid: 2.0,
				current_ask: 3.0,
				base_volume: 4.0,
			}
		}
	"""
	@spec generic_market_pair(strings: [String.t], numbers: [number], exchange: atom) :: Pair.t
	def generic_market_pair(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv], exchange: exchange) do
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
	@spec maybe_update(ExchangeMarket.t) :: any
	def maybe_update(%ExchangeMarket{pairs: pairs} = x) do
		case pairs do
			nil ->
				nil
			[] ->
				nil
			_ ->
				Market.Client.update(x)
		end
	end

	@doc """
	Makes an index of tokens (symbol => address) based on data received from the Kyber API.
	"""
	@spec index_currencies([map]) :: %{required(String.t) => String.t}
	def index_currencies(currencies) do
		Enum.reduce(currencies, %{}, fn (c, acc) ->
			Map.put(acc, c["symbol"], c["address"])
		end)
	end
end
