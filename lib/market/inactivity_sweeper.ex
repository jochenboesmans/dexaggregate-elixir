defmodule Dexaggregatex.Market.InactivitySweeper do
  defmodule Result do
    alias Dexaggregatex.Market.Structs.{Market, Pair}

    @moduledoc """
    Data structure representing a the result of a sweep operation.
    """
    @enforce_keys [:swept_market, :removed_pairs]
    defstruct [:swept_market, :removed_pairs]

    @typedoc """
    * swept_market: data structure representing market without the inactive data.
    * removed_pairs: data structure representing the pairs removed during sweeping.
    """
    @type t :: %__MODULE__{swept_market: Market.t(), removed_pairs: [Pair.t()]}
  end

  @moduledoc """
  Routinely sweeps inactive pairs from the market.
  """
  use Task

  alias Dexaggregatex.Market.Client, as: MarketClient
  alias Dexaggregatex.Market.Structs.{Market, Pair, ExchangeMarketData}
  alias Dexaggregatex.Market.InactivitySweeper.Result

  @sweep_interval 60_000
  @max_age 3_600_000

  # Make private functions testable.
  @compile if Mix.env() == :test, do: :export_all

  @doc """
  Starts an InactivitySweeper process linked to the caller process.
  """
  @spec start_link(any) :: {:ok, pid}
  def start_link(_arg) do
    Task.start_link(__MODULE__, :sweep, [])
  end

  @doc """
  Routinely sweeps inactive data from a market.
  """
  @spec sweep() :: :ok
  def sweep() do
    Stream.interval(@sweep_interval)
    |> Stream.map(fn _x -> MarketClient.market() end)
    |> Enum.each(fn x -> sweep_market(x) end)
  end

  @doc """
  Sweeps inactive data from a market.
  """
  @spec sweep_market(Market.t()) :: :ok
  defp sweep_market(%Market{pairs: pairs}) do
    Enum.reduce(pairs, %Result{swept_market: %Market{pairs: %{}}, removed_pairs: []}, fn {p_id,
                                                                                          %Pair{
                                                                                            market_data:
                                                                                              pmd
                                                                                          } = p},
                                                                                         %Result{
                                                                                           swept_market:
                                                                                             %Market{
                                                                                               pairs:
                                                                                                 sp
                                                                                             } =
                                                                                               sm,
                                                                                           removed_pairs:
                                                                                             rp
                                                                                         } =
                                                                                           result_acc ->
      swept_pmd =
        Enum.filter(pmd, fn {_e, %ExchangeMarketData{timestamp: ts}} ->
          :os.system_time(:millisecond) - ts < @max_age
        end)
        |> Enum.into(%{})

      case Enum.count(swept_pmd) do
        0 ->
          %{result_acc | removed_pairs: [p | rp]}

        _ ->
          %{
            result_acc
            | swept_market: %{sm | pairs: Map.put(sp, p_id, %{p | market_data: swept_pmd})}
          }
      end
    end)
    |> MarketClient.eat_swept_market()
  end
end
