defmodule Dexaggregatex.API.RestController do
  @moduledoc """
  Controller for REST API requests.
  """
  alias Dexaggregatex.Market.Client, as: MarketClient
  alias Dexaggregatex.API

  import API.Format
  use API, :controller

  @doc """
  Resolve a request to the root route.
  """
  def root(conn, _params) do
    unsuccessful_fetch(conn)
  end

  @typedoc """
  All excepted top-level parameters.
  """
  @type top_param :: :last_update | :exchanges | :rebased_market | :market
  @doc """
  Resolve a request to a route with at least one parameter.
  """
  @spec get(Plug.Conn.t(), Plug.Conn.params()) :: Plug.Conn.t()
  def get(conn, %{"what_to_get" => what} = params) do
    case what do
      "last_update" -> successful_fetch(conn, String.to_atom(what))
      "exchanges" -> successful_fetch(conn, String.to_atom(what))
      "rebased_market" -> successful_fetch(conn, String.to_atom(what), params)
      "market" -> successful_fetch(conn, String.to_atom(what))
      _ -> unsuccessful_fetch(conn)
    end
  end

  @doc """
  Update conn to include response upon unsuccessful fetch.
  """
  @spec unsuccessful_fetch(Plug.Conn.t()) :: Plug.Conn.t()
  defp unsuccessful_fetch(conn) do
    send_resp(conn, 404, "Please use a valid route.")
  end

  @doc """
  Update conn to include response upon successful fetch.
  """
  @spec successful_fetch(Plug.Conn.t(), top_param, Plug.Conn.params()) :: Plug.Conn.t()
  defp successful_fetch(conn, top_param, params \\ %{}) do
    data =
      case top_param do
        :last_update ->
          get_last_update()

        :exchanges ->
          get_exchanges()

        :rebased_market ->
          case params do
            %{"rebase_address" => ra} -> get_rebased_market(ra)
            _ -> unsuccessful_fetch(conn)
          end

        :market ->
          get_market()
      end
      |> Poison.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, data)
  end

  @spec get_market() :: map
  defp get_market() do
    MarketClient.market() |> format_market()
  end

  @spec get_rebased_market(String.t()) :: map
  defp get_rebased_market(ra) do
    MarketClient.rebased_market(%{rebase_address: ra}) |> format_rebased_market()
  end

  @spec get_exchanges() :: [String.t()]
  defp get_exchanges() do
    MarketClient.exchanges_in_market() |> format_exchanges_in_market()
  end

  @spec get_last_update() :: map
  defp get_last_update() do
    MarketClient.last_update() |> format_last_update()
  end
end
