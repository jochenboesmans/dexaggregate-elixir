defmodule Market do
  @moduledoc false

  use GenServer

  def get(pid) do
    GenServer.call(pid, :get)
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
      old_entry = acc["#{p.base_symbol}/#{p.quote_symbol}"] || %{}
      new_entry = Map.put(old_entry, e, p)
      acc = Map.put(acc, "#{p.base_symbol}/#{p.quote_symbol}", new_entry)
    end)
    IO.inspect(market)
  end


end
