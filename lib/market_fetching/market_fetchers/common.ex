defmodule Dexaggregatex.MarketFetching.Common do
	@moduledoc """
		Generic functions used for market fetching.
	"""
	alias Dexaggregatex.MarketFetching.Structs.{
		Pair, ExchangeMarket, PairMarketData}

	import Dexaggregatex.MarketFetching.Util

	@doc """
		Determines whether a given string has a valid value to be included in the market.

	## Examples
		iex> Dexaggregatex.MarketFetching.Util.valid_string?("ETH")
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
				Dexaggregatex.Market.update(x)
		end
	end
end
