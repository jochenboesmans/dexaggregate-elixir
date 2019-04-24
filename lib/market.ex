defmodule Market do
  @moduledoc """
    GenServer maintaining the global market.
  """

  use GenServer
  alias MarketFetching.ExchangeMarket, as: ExchangeMarket

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
  def handle_cast({:update, exchange_market}, %{market: prev_market, rebased_market: _}) do
    {:noreply, merge(prev_market, exchange_market)}
  end

  defp merge(prev_market, %ExchangeMarket{exchange: e, market: m}) do
    market = Enum.reduce(m, prev_market, fn (p, acc) ->
      pair_id = Base.encode64(:crypto.hash(:sha512, "#{p.base_symbol}/#{p.quote_symbol}"))
      old_entry = get_old_entry(acc, pair_id)
      new_entry = %{old_entry | market_data: Map.put(old_entry[:market_data], e, p)}
      Map.put(acc, pair_id, new_entry)
    end)

    dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
    rebased_market = Rebasing.rebase_market(market, dai_address)

    %{market: market, rebased_market: rebased_market}
  end

  defp get_old_entry(acc, key) do
    case Map.has_key?(acc, key) do
      true -> acc[key]
      false -> %{}
    end
  end


end
