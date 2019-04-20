defmodule Market do
  @moduledoc false

  use GenServer

  def get() do
    GenServer.call(__MODULE__, :get)
  end

  def update(exchange_market) do
    %ExchangeMarket{exchange: exchange, market: _} = exchange_market

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

  def init(initial_market) do
    {:ok, %{}}
  end

  def handle_call(:get, _from, market) do
    {:reply, market, market}
  end

  def handle_cast({:update, exchange_market}, market) do
    {:noreply, merge(market, exchange_market)}
  end

  defp merge(market, exchange_market) do
    %ExchangeMarket{exchange: e, market: m} = exchange_market

    market = Enum.reduce(m, market, fn (p, acc) ->
      old_entry = get_old_entry(acc, "#{p.base_symbol}/#{p.quote_symbol}")
      new_entry = Map.put(old_entry, e, p)
      acc = Map.put(acc, "#{p.base_symbol}/#{p.quote_symbol}", new_entry)
    end)
  end

  defp get_old_entry(acc, key) do
    case Map.has_key?(acc, key) do
      true -> acc[key]
      false -> %{}
    end
  end


end
