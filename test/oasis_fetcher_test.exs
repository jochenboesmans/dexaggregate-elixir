defmodule OasisFetcherTests do
	use ExUnit.Case
	alias MarketFetching.MarketFetchers.OasisFetcher, as: OasisFetcher
	doctest OasisFetcher

	test "transform_rate case 1: returns nil when passed nil as argument" do
		assert OasisFetcher.transform_rate(nil) == nil
	end
	test "transform_rate case 2: returns nil when passed an empty string as an argument" do
		assert OasisFetcher.transform_rate("") == nil
	end
	test "transform_rate case 3: returns a float value containing the inverse of the value of the passed in string" do
		assert OasisFetcher.transform_rate("608.46366185") === 0.0016434835187356227
	end
	test "transform_rate case 4: returns the inverse of the passed in value when it's a float" do
		assert OasisFetcher.transform_rate(608.46366185) === 0.0016434835187356227
	end

end