defmodule OasisFetcherTests do
	use ExUnit.Case, async: true
	alias MarketFetching.MarketFetchers.OasisFetcher, as: OF
	doctest OF

	setup do
		{:ok, pid} = OF.start_link(nil)
		{:ok, pid: pid}
	end

	describe "transform_rate/1" do
		@describetag :transform_rate

		test "#1: returns nil for nil" do
			assert OF.transform_rate(nil) == nil
		end
		test "#2: returns nil for \"\"" do
			assert OF.transform_rate("") == nil
		end
		test "#3: returns a float value containing the inverse of the value of the passed in string" do
			assert OF.transform_rate("608.46366185") === 0.0016434835187356227
		end
		test "#4: returns the inverse of the passed in value for a float" do
			assert OF.transform_rate(608.46366185) === 0.0016434835187356227
		end
		test "#5: returns the inverse of the passed in value for an integer" do
			assert OF.transform_rate(608) === 0.001644736842105263
		end
	end

	describe "fetch_and_decode/1" do
		test "#1: returns empty map on unexisting pair" do
			assert OF.fetch_and_decode("http://api.oasisdex.com/v1/markets/MKR/MKR") == %{}
		end
		test "#2: returns a map with expected keys and values on existing pair" do
			result = OF.fetch_and_decode("http://api.oasisdex.com/v1/markets/MKR/DAI")
			expected_keys = MapSet.new(["pair", "price", "last", "vol", "ask", "bid", "low", "high"])
			Enum.each(expected_keys, fn k ->
				assert is_binary(result[k])
				assert Map.has_key?(result, k)
			end)
		end
	end

	describe "fetch_market/0" do
		test "#1: returns a list with a length corresponding to pairs/0" do
			assert Enum.count(OF.pairs()) === Enum.count(OF.fetch_market())
		end
	end


end