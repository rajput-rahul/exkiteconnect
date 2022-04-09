defmodule KiteConnectTest do
  use ExUnit.Case

  import Tesla.Mock
  alias Zerodha.{KiteConnect, Params, Constants}
  alias Tesla.Client

  @root_url Application.get_env(:zerodha, :base_url, Constants.default_root_url())
  @login_url Constants.default_login_uri()
  setup do
    mock(fn
      %{method: :get, url: "#{@login_url}"} ->
        %Tesla.Env{status: 200, body: "hello"}

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

    :ok
  end

  test "should return Params struct" do
    assert %Params{api_key: api_key} = KiteConnect.init("testapikey")
    assert api_key == "testapikey"

    assert %Params{access_token: access_token} = KiteConnect.init("testapikey", "testaccesstoken")

    assert access_token == "testaccesstoken"
  end

  test "should return params struct with client" do
    assert %Params{api_key: api_key, client: %Client{} = client, access_token: access_token} =
             KiteConnect.setup("testapikey", "testapisecret")

    assert api_key == "testapikey"
    assert access_token == "yyyyyy"

    assert client
  end
end
