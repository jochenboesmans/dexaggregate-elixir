defmodule Market do
  @moduledoc """
    GenServer maintaining the global market.
  """

  use GenServer
  alias MarketFetching.ExchangeMarket, as: ExchangeMarket
  import Util

  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def update(exchange_market) do
    GenServer.cast(__MODULE__, {:update, exchange_market})
  end

  def start_link(_options) do
    children = []
    options = [
      strategy: :one_for_one,
      name: __MODULE__
    ]
    GenServer.start_link(__MODULE__, children, options)
  end

  @impl true
  def init(_initial_market) do
    {:ok, %{}}
  end

  @impl true
  def handle_call(:get, _from, market) do
    {:reply, market, market}
  end

  @impl true
  def handle_cast({:update, exchange_market}, prev_state) do
    {:noreply, merge(prev_state, exchange_market)}
  end

  def merge(%{market: prev_market}, %ExchangeMarket{exchange: e, market: m}) do
    market = Enum.reduce(m, prev_market, fn (p, acc) ->
      id = pair_id(p)
      updated_market_pair =
        case Map.has_key?(acc, id) do
          false ->
            %{
              base_symbol: p.base_symbol,
              base_address: p.base_address,
              quote_address: p.quote_address,
              quote_symbol: p.quote_symbol,
              market_data: %{
                e => p.market_data
              }
            }
          true ->
            %{acc[id] | market_data: Map.put(acc[id][:market_data], e, p.market_data)}
        end
      Map.put(acc, id, updated_market_pair)
    end)
    IO.inspect(market)

    dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
    rebased_market = Rebasing.rebase_market(dai_address, market)

    %{market: market, rebased_market: rebased_market}
  end

  defp get_old_entry(acc, key) do
    case Map.has_key?(acc, key) do
      true -> acc[key]
      false -> %{}
    end
  end


end
