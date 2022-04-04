defmodule Zerodha.KiteConnect do
  @moduledoc """
  The Kite Connect API wrapper class_
    In production, you may initialise a single instance of this class per `api_key`_
  """

  import Zerodha.Constants
  use Tesla

  def orders(client) do
    get(client, routes()[:orders])
  end

  def generate_session(), do: true

  def client(_token) do
    middleware = [
      {Tesla.Middleware.BaseUrl, Application.get_env(:zerodha, :base_url, default_root_url())},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end
end
