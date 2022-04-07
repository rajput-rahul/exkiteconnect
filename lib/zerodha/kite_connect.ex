defmodule Zerodha.KiteConnect do
  @moduledoc """
  The Kite Connect API wrapper class_
    In production, you may initialise a single instance of this class per `api_key`_
  """

  alias Zerodha.Constants
  alias Zerodha.Params
  alias Jason
  use Tesla

  @doc """
  Need to add default values for access token and api key from config file.
  """
  def init(
        api_key,
        access_token \\ nil,
        root_url \\ Constants.default_root_url(),
        debug \\ false,
        disable_ssl \\ false,
        timeout \\ Constants.default_timeout()
      ) do
    %Params{
      access_token: access_token,
      api_key: api_key,
      debug: debug,
      disable_ssl: disable_ssl,
      root_url: root_url,
      timeout: timeout
    }
  end

  def setup(%Params{} = params, api_secret \\ nil) do
    resp = get(login_url(params))

    Jason.decode(resp.body)
    |> IO.inspect()

    # just imagine it works
    request_token = resp.body.request_token

    params
    |> set_client(create_client())
    |> generate_session(request_token, api_secret)

    # need to parse this result and apply the access token.
  end

  def orders(client) do
    get(client, Constants.routes()[:orders])
  end

  def generate_session(%Params{} = params, request_token, api_secret) do
    checksum = generate_checksum(params.api_key <> request_token <> api_secret)

    params.client
    |> post(Constants.routes()[:api_token], %{
      api_key: params.api_key,
      checksum: checksum,
      request_token: request_token
    })
  end

  defp generate_checksum(value) do
    :sha256
    |> :crypto.hash(value)
    |> Base.encode16()
  end

  def create_client() do
    middleware = [
      {Tesla.Middleware.BaseUrl,
       Application.get_env(:zerodha, :base_url, Constants.default_root_url())},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end

  @doc """
  Set a callback hook for session (`TokenError` -- timeout, expiry etc.) errors.
  An `access_token` (login session) can become invalid for a number of
  reasons, but it doesn't make sense for the client to
  try and catch it during every API call.

  A callback method that handles session errors
  can be set here and when the client encounters
  a token error at any point, it'll be called.

  This callback, for instance, can log the user out of the UI,
  clear session cookies, or initiate a fresh login.
  """
  def set_session_expiry_hook(%Params{} = params, f) do
    fun_info = :erlang.fun_info(f)

    if(!function_exported?(fun_info[:module], fun_info[:name], fun_info[:arity])) do
      raise "Invalid function passed to session_expiry_hook"
    else
      params
      |> Map.put(:session_expiry_hook, f)
    end
  end

  def set_client(%Params{} = params, clnt) do
    params
    |> Map.put(:client, clnt)
  end

  def set_response(%Params{} = params, response) do
    params
    |> Map.put(:response, response)
  end

  def set_api_key(%Params{} = params, api_key) do
    params
    |> Map.put(:api_key, api_key)
  end

  def set_access_token(%Params{} = params, access_token) do
    params
    |> Map.put(:access_token, access_token)
  end

  @doc """
  I am not planning to use this function so probably this would be discontinued in future.
  """
  def set_proxies(%Params{} = params, proxies) do
    params
    |> Map.put(:proxies, proxies)
  end

  @doc """
  It will enable debug mode, can be used in development. We can also pass value of debug
  variable to be true during init function.
  """
  def enable_debug(%Params{} = params) do
    params
    |> Map.put(:debug, true)
  end

  def login_url(%Params{api_key: api_key}) do
    "#{Constants.default_login_uri()}?api_key=#{api_key}&v=3"
  end

  @doc """
  Kill the session by invalidating the access token.
  - `access_token` to invalidate. Default is the active `access_token`.
  """
  def invalidate_access_token(%Params{
        access_token: access_token,
        api_key: api_key,
        client: client
      }) do
    client
    |> delete!(Constants.routes()[:api_token_invalidate], %{
      api_key: api_key,
      access_token: access_token
    })
  end

  def invalidate_access_token(
        %Params{api_key: api_key, client: client},
        access_token
      ) do
    client
    |> delete!(Constants.routes()[:api_token_invalidate], %{
      api_key: api_key,
      access_token: access_token
    })
  end

  @doc """
    Renew expired `refresh_token` using valid `refresh_token`.
    - `refresh_token` is the token obtained from previous successful login flow. (access_token)
    - `api_secret` is the API api_secret issued with the API key.
  """
  def renew_access_token, do: true

  def profile(%Params{client: client}) do
    client
    |> get!(Constants.routes()[:user_profile])
  end

  @doc """
  Get account balance and cash margin details for a particular segment.
  """
  def margins(%Params{client: client}) do
    client
    |> get!(Constants.routes()[:user_margins])
  end

  @doc """
  Get account balance and cash margin details for a particular segment.
  - `segment` is the trading segment (eg: equity or commodity)
  """
  def margins(%Params{client: client}, segment) do
    client
    |> get!(Constants.routes()[:user_margins], %{segment: segment})
  end

  @doc """
  Place an order
  """
  def place_order(
        %Params{client: client},
        variety,
        exchange,
        tradingsymbol,
        transaction_type,
        quantity,
        product,
        order_type,
        price \\ nil,
        validity \\ nil,
        disclosed_quantity \\ nil,
        trigger_price \\ nil,
        squareoff \\ nil,
        stoploss \\ nil,
        trailing_stoploss \\ nil,
        tag \\ nil
      ) do
    order_params =
      %{}
      |> Map.put(:variety, variety)
      |> Map.put(:exchange, exchange)
      |> Map.put(:tradingsymbol, tradingsymbol)
      |> Map.put(:transaction_type, transaction_type)
      |> Map.put(:quantity, quantity)
      |> Map.put(:product, product)
      |> Map.put(:order_type, order_type)
      |> Map.put(:price, price)
      |> Map.put(:validity, validity)
      |> Map.put(:disclosed_quantity, disclosed_quantity)
      |> Map.put(:trigger_price, trigger_price)
      |> Map.put(:squareoff, squareoff)
      |> Map.put(:stoploss, stoploss)
      |> Map.put(:trailing_stoploss, trailing_stoploss)
      |> Map.put(:tag, tag)
      |> Enum.filter(fn {_, v} -> !is_nil(v) end)
      |> Enum.into(%{})

    # TODO: need to put url args
    # url_args={"variety": variety}
    client
    |> post!(Constants.routes()[:order_place], order_params)
    |> IO.inspect()
  end
end
