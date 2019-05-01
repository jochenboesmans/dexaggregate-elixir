defmodule Market do
  @moduledoc """
    GenServer maintaining the global market.
  """

  use GenServer
  alias MarketFetching.ExchangeMarket, as: ExchangeMarket
  alias Market.Rebasing, as: Rebasing
  import Market.Util

  def get(atom) do
    case atom do
      :market ->
        GenServer.call(__MODULE__, :get_market)
      :rebased_market ->
        GenServer.call(__MODULE__, :get_rebased_market)
      _ ->
        nil
    end

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
    {:ok, %{market: %{}, rebased_market: %{}}}
  end

  @impl true
  def handle_call(:get_market, _from, %{market: m} = state) do
    {:reply, format_market(m), state}
  end

  @impl true
  def handle_call(:get_rebased_market, _from, %{rebased_market: rm} = state) do
    {:reply, format_market(rm), state}
  end

  defp format_market(m) do
    Map.values(m)
    |> Enum.sort_by(&combined_volume_across_exchanges/1, &>=/2)
  end

  defp combined_volume_across_exchanges(p) do
    Enum.reduce(p.market_data, 0, fn ({_exchange, emd}, acc) ->
      acc + emd.base_volume
    end)
  end

  @impl true
  def handle_cast({:update, exchange_market}, prev_state) do
    {:noreply, merge(prev_state, exchange_market)}
  end

  def merge(%{market: prev_market}, %ExchangeMarket{market: m}) do
    market = Enum.reduce(m, prev_market, fn (p, acc) ->
      %MarketFetching.Pair{
        base_address: ba,
        quote_address: qa,
        base_symbol: bs,
        quote_symbol: qs,
        market_data: %MarketFetching.PairMarketData{
          exchange: ex,
          last_price: lp,
          current_bid: cb,
          current_ask: ca,
          base_volume: bv,
          quote_volume: qv
        }
      } = p

      id = pair_id(ba, qa)
      emd = %Market.ExchangeMarketData{
        last_price: lp,
        current_bid: cb,
        current_ask: ca,
        base_volume: bv,
        quote_volume: qv
      }

      market_entry =
        case Map.has_key?(acc, id) do
          false ->
            %Market.Pair{
              base_symbol: bs,
              base_address: ba,
              quote_address: qa,
              quote_symbol: qs,
              market_data: %{
                ex => emd
              }
            }
          true ->
            %{acc[id] | market_data: Map.put(acc[id].market_data, ex, emd)}
        end
      Map.put(acc, id, market_entry)
    end)

    dai_address = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
    rebased_market = Rebasing.rebase_market(dai_address, market, 4)

    %{market: market, rebased_market: rebased_market}
  end
end
