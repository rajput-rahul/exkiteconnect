defmodule OrdersTest do
  use ExUnit.Case

  import Tesla.Mock
  alias Zerodha.{KiteConnect, Params, Constants}
  alias Tesla.Client

  @root_url Application.get_env(:zerodha, :base_url, Constants.default_root_url())

  setup do
    mock(fn
      %{method: :get, url: "#{@root_url}/orders"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "data" => [
              %{
                "order_id" => "151220000000000",
                "price" => 0,
                "quantity" => 75,
                "status" => "REJECTED",
                "tradingsymbol" => "ACC",
                "variety" => "regular"
              }
            ],
            "status" => "success"
          }
        }

      %{method: :post, url: "#{@root_url}/session/token"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            status: "success",
            data: %{
              user_id: "XX000",
              user_name: "Kite Connect",
              user_shortname: "Kite",
              email: "kite@kite.trade",
              user_type: "investor",
              broker: "ZERODHA",
              api_key: "xxxxxx",
              access_token: "yyyyyy",
              login_time: "2018-01-01 16:15:14"
            }
          }
        }
    end)

    params = KiteConnect.setup("apikey", "apisecret")

    {:ok, params: params}
  end

  test "should return list of orders", %{params: params} do
    IO.inspect(params.client)
    response = KiteConnect.orders(params)
    IO.puts("#{@root_url}/orders")
    assert %{
             "data" => [
               %{
                 "order_id" => "151220000000000",
                 "quantity" => 75,
                 "status" => "REJECTED",
                 "validity" => "DAY",
                 "tradingsymbol" => "ACC"
               }
             ],
             "status" => "success"
           } in response.body
  end
end
