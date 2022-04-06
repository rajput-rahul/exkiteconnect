defmodule Zerodha.KiteConnect do
  @moduledoc """
  The Kite Connect API wrapper class_
    In production, you may initialise a single instance of this class per `api_key`_
  """

  alias Zerodha.Constants
  alias Zerodha.Params
  use Tesla

  @doc """
  Need to add default values for access token and api key from config file.
  """
  def init(
        access_token,
        api_key,
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

  def orders(client) do
    get(client, Constants.routes()[:orders])
  end

  def generate_session(), do: true

  def client(_token) do
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
end
