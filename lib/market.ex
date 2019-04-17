defmodule Market do
  @moduledoc false

  use GenServer

  def get(pid) do
    GenServer.call(pid, :get)
  end

  def update(pid, exchange_market) do
    GenServer.cast(pid, {:update, exchange_market})
  end

  def start_link(_options) do
    children = [
      {FetcherSupervisor, name: FetcherSupervisor},
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def init(initial_market) do
    {:ok, initial_market}
  end

  def handle_call(:get, _from, market) do
    {:reply, market, market}
  end

  def handle_cast({:update, exchange_market}, market) do
    {:noreply, merge(market, exchange_market)}
  end

  defp merge(market, exchange_market) do
    %ExchangeMarket{exchange: e, market: m} = exchange_market

    Enum.reduce(m, fn p, market ->
      old_entry = market["#{p.base_symbol}/#{p.quote_symbol}"] || %{}
      new_entry = Map.put(old_entry, e, p)
      market = Map.put(market, "#{p.base_symbol}/#{p.quote_symbol}", new_entry)
    end)
  end


end
