defmodule Zerodha.KiteConnect do
  @moduledoc """
  The Kite Connect API wrapper class_
    In production, you may initialise a single instance of this class per `api_key`_
  """

  alias Zerodha.Constants
  alias Zerodha.Params
  alias Jason
  use Tesla

  @routes Constants.routes()

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

  def generate_session(%Params{} = params, request_token, api_secret) do
    checksum = generate_checksum(params.api_key <> request_token <> api_secret)

    params.client
    |> post(@routes[:api_token], %{
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
    |> delete(@routes[:api_token_invalidate], %{
      api_key: api_key,
      access_token: access_token
    })
  end

  def invalidate_access_token(
        %Params{api_key: api_key, client: client},
        access_token
      ) do
    client
    |> delete(@routes[:api_token_invalidate], %{
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
    |> get(@routes[:user_profile])
  end

  @doc """
  Get account balance and cash margin details for a particular segment.
  """
  def margins(%Params{client: client}) do
    client
    |> get(@routes[:user_margins])
  end

  @doc """
  Get account balance and cash margin details for a particular segment.
  - `segment` is the trading segment (eg: equity or commodity)
  """
  def margins(%Params{client: client}, segment) do
    client
    |> get(@routes[:user_margins], %{segment: segment})
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

    client
    |> post(@routes[:order_place], order_params, query: %{variety: variety})
    |> IO.inspect()

    # We need to extract order_id from the response
  end

  @doc """
  Modifies an open order
  """
  def modify_order(
        %Params{client: client},
        variety,
        order_id,
        parent_order_id \\ nil,
        quantity \\ nil,
        order_type \\ nil,
        price \\ nil,
        validity \\ nil,
        disclosed_quantity \\ nil,
        trigger_price \\ nil
      ) do
    order_params =
      %{}
      |> Map.put(:variety, variety)
      |> Map.put(:order_id, order_id)
      |> Map.put(:quantity, quantity)
      |> Map.put(:parent_order_id, parent_order_id)
      |> Map.put(:order_type, order_type)
      |> Map.put(:price, price)
      |> Map.put(:validity, validity)
      |> Map.put(:disclosed_quantity, disclosed_quantity)
      |> Map.put(:trigger_price, trigger_price)
      |> Enum.filter(fn {_, v} -> !is_nil(v) end)
      |> Enum.into(%{})

    client
    |> put(@routes[:order_modify], order_params, query: %{variety: variety, order_id: order_id})
    |> IO.inspect()

    # We need to extract order_id from the response
  end

  @doc """
  Cancel an order.
  """
  def cancel_order(%Params{client: client}, variety, order_id, parent_order_id \\ nil) do
    client
    |> delete(@routes[:order_cancel], %{parent_order_id: parent_order_id})

    # |> delete!(@routes[:order_cancel], %{parent_order_id: parent_order_id},
    #   query: %{variety: variety, order_id: order_id}
    # )
    # TODO: need to put url args
    # , query: %{variety: variety, order_id: order_id}
  end

  @doc """
  Exit a BO/CO order.
  """
  def exit_order(%Params{} = params, variety, order_id, parent_order_id \\ nil) do
    cancel_order(params, variety, order_id, parent_order_id)
  end

  defp format_response, do: true

  @doc """
  Get list of orders.
  """
  def orders(%Params{client: client}) do
    format_response()

    client
    |> get(@routes[:orders])
  end

  @doc """
  Get history of individual order.
  - `order_id` is the ID of the order to retrieve order history.
  """
  def order_history(%Params{client: client}, order_id) do
    client
    |> get(@routes[:orders_info], query: %{order_id: order_id})
  end

  @doc """
  Retrieve the list of trades executed (all or ones under a particular order).
  An order can be executed in tranches based on market conditions.
  These trades are individually recorded under an order.
  """
  def trades(%Params{client: client}) do
    client
    |> get(@routes[:trades])
  end

  @doc """
  Retrieve the list of trades executed for a particular order.
  - `order_id` is the ID of the order to retrieve trade history.
  """
  def order_trades(%Params{client: client}, order_id) do
    client
    |> get(@routes[:order_trades], query: %{order_id: order_id})
  end

  @doc """
  Retrieve the list of positions.
  """
  def positions(%Params{client: client}) do
    client
    |> get(@routes[:portfolio_positions])
  end

  @doc """
  Retrieve the list of equity holdings.
  """
  def holdings(%Params{client: client}) do
    client
    |> get(@routes[:portfolio_holdings])
  end

  @doc """
  Modify an open position's product type.
  """
  def convert_position(
        %Params{client: client},
        exchange,
        tradingsymbol,
        transaction_type,
        position_type,
        quantity,
        old_product,
        new_product
      ) do
    order_params =
      %{}
      |> Map.put(:exchange, exchange)
      |> Map.put(:tradingsymbol, tradingsymbol)
      |> Map.put(:transaction_type, transaction_type)
      |> Map.put(:position_type, position_type)
      |> Map.put(:quantity, quantity)
      |> Map.put(:old_product, old_product)
      |> Map.put(:new_product, new_product)

    # |> Enum.filter(fn {_, v} -> !is_nil(v) end)
    # |> Enum.into(%{})

    client
    |> put(@routes[:portfolio_positions_convert], order_params)
    |> IO.inspect()
  end

  @doc """
  Get all mutual fund orders.
  """
  def mf_orders(%Params{client: client}) do
    client
    |> get(@routes[:mf_orders])
  end

  @doc """
  Get individual mutual fund order info.
  """
  def mf_orders(%Params{client: client}, order_id) do
    client
    |> get(@routes[:mf_order_info], query: %{order_id: order_id})
  end

  @doc """
  Place a mutual fund order.
  """
  def place_mf_order(
        %Params{client: client},
        tradingsymbol,
        transaction_type,
        quantity \\ nil,
        amount \\ nil,
        tag \\ nil
      ) do
    order_params =
      %{}
      |> Map.put(:tradingsymbol, tradingsymbol)
      |> Map.put(:transaction_type, transaction_type)
      |> Map.put(:amount, amount)
      |> Map.put(:quantity, quantity)
      |> Map.put(:tag, tag)

    # |> Enum.filter(fn {_, v} -> !is_nil(v) end)
    # |> Enum.into(%{})

    client
    |> post(@routes[:mf_order_place], order_params)
    |> IO.inspect()
  end

  @doc """
  Cancel a mutual fund order.
  """
  def cancel_mf_order(%Params{client: client}, order_id) do
    client
    |> get(@routes[:mf_order_cancel], query: %{order_id: order_id})
  end

  @doc """
  Get list of all mutual fund SIP's.
  """
  def mf_sips(%Params{client: client}) do
    client
    |> get(@routes[:mf_sips])
  end

  @doc """
  Get individual mutual fund SIP info.
  """
  def mf_sips(%Params{client: client}, sip_id) do
    client
    |> get(@routes[:mf_sip_info], query: %{sip_id: sip_id})
  end

  @doc """
  Place a mutual fund SIP.
  """
  def place_mf_sip(
        %Params{client: client},
        tradingsymbol,
        amount,
        installments,
        frequency,
        initial_amount \\ nil,
        installment_day \\ nil,
        tag \\ nil
      ) do
    order_params =
      %{}
      |> Map.put(:tradingsymbol, tradingsymbol)
      |> Map.put(:instalments, installments)
      |> Map.put(:amount, amount)
      |> Map.put(:frequency, frequency)
      |> Map.put(:initial_amount, initial_amount)
      |> Map.put(:instalment_day, installment_day)
      |> Map.put(:tag, tag)

    # |> Enum.filter(fn {_, v} -> !is_nil(v) end)
    # |> Enum.into(%{})

    client
    |> post(@routes[:mf_sip_place], order_params)
    |> IO.inspect()
  end

  @doc """
  Place a mutual fund SIP.
  """
  def modify_mf_sip(
        %Params{client: client},
        sip_id,
        amount \\ nil,
        status \\ nil,
        installments \\ nil,
        frequency \\ nil,
        installment_day \\ nil
      ) do
    order_params =
      %{}
      |> Map.put(:status, status)
      |> Map.put(:instalments, installments)
      |> Map.put(:amount, amount)
      |> Map.put(:frequency, frequency)
      |> Map.put(:instalment_day, installment_day)

    client
    |> put(@routes[:mf_sip_place], order_params, query: %{sip_id: sip_id})
    |> IO.inspect()
  end

  @doc """
  Cancel a mutual fund SIP.
  """
  def cancel_mf_sip(%Params{client: client}, sip_id) do
    client
    |> delete(@routes[:mf_sip_cancel], query: %{sip_id: sip_id})
  end

  @doc """
  Get list of mutual fund holdings.
  """
  def mf_holdings(%Params{client: client}) do
    client
    |> get(@routes[:mf_holdings])
  end

  @doc """
  Get list of mutual fund instruments.
  """
  def mf_instruments(%Params{client: client}) do
    client
    |> get(@routes[:mf_instruments])
  end

  def instruments(%Params{client: client}) do
    client
    |> get(@routes[:market_instruments_all])
  end

  @doc """
  Retrieve the list of market instruments available to trade.

  Note that the results could be large, several hundred KBs in size,
  with tens of thousands of entries in the list.

  - `exchange` is specific exchange to fetch (Optional)
  """
  def instruments(%Params{client: client}, exchange) do
    client
    |> get(@routes[:market_instruments], query: %{exchange: exchange})
  end

  @doc """
  Retrieve quote for list of instruments.

  - `instruments` is a list of instruments, Instrument are in the format of `exchange:tradingsymbol`. For example NSE:INFY
  """
  # def quote(%Params{client: client}, [ins | _]) when not is_nil(ins) and is_list(ins) do
  #   # If first element is a list then accept it as instruments list for legacy reason
  #   client
  #   |> get(@routes[:market_quote], %{i: ins})
  # end
  def quote(%Params{client: client}, [] = intruments_list) when is_list(intruments_list) do
    client
    |> get(@routes[:market_quote], %{i: intruments_list})

    # TODO: need to format data
  end

  @doc """
  Retrieve OHLC and market depth for list of instruments.

  - `instruments` is a list of instruments, Instrument are in the format of `exchange:tradingsymbol`. For example NSE:INFY
  """
  def ohlc(%Params{client: client}, [] = intruments_list) when is_list(intruments_list) do
    client
    |> get(@routes[:market_quote_ohlc], %{i: intruments_list})
  end

  @doc """
  Retrieve last price for list of instruments.

  - `instruments` is a list of instruments, Instrument are in the format of `exchange:tradingsymbol`. For example NSE:INFY
  """
  def ltp(%Params{client: client}, [] = intruments_list) when is_list(intruments_list) do
    client
    |> get(@routes[:market_quote_ltp], %{i: intruments_list})
  end

  @doc """
  Retrieve historical data (candles) for an instrument.
  Although the actual response JSON from the API does not have field
  names such has 'open', 'high' etc., this function call structures
  the data into an array of objects with field names. For example:
  - `instrument_token` is the instrument identifier (retrieved from the instruments()) call.
  - `from_date` is the From date (datetime struct).
  - `to_date` is the To date (datetime struct).
  - `interval` is the candle interval (minute, day, 5 minute etc.).
  - `continuous` is a boolean flag to get continuous data for futures and options instruments.
  - `oi` is a boolean flag to get open interest.
  """
  def historical_data(
        %Params{client: client},
        _instrument_token,
        %DateTime{} = from_date,
        %DateTime{} = to_date,
        interval,
        continuous \\ false,
        oi \\ false
      ) do
    date_string_format = "%y-%m-%d %I:%M:%S"
    from_date_string = Calendar.strftime(from_date, date_string_format)
    to_date_string = Calendar.strftime(to_date, date_string_format)

    params = %{
      from: from_date_string,
      to: to_date_string,
      interval: interval,
      continuous: if(continuous, do: 1, else: 0),
      oi: if(oi, do: 1, else: 0)
    }

    client
    |> get(@routes[:market_historical], params)

    # TODO: need to add url_args
    # {"instrument_token": instrument_token, "interval": interval}
    # Need to format this data as well
  end

  @doc """
  "Retrieve the buy/sell trigger range for Cover Orders.
  TODO: Need to implement
  """
  def trigger_range(), do: true

  @doc """
  Fetch list of GTT existing in an account.
  """
  def get_gtts(%Params{client: client}) do
    client
    |> get(@routes[:gtt])
  end

  @doc """
  Fetch list of a GTT.
  """
  def get_gtt(%Params{client: client}, trigger_id) do
    client
    |> get(@routes[:gtt_info], query: %{trigger_id: trigger_id})
  end

  @doc """
  Get GTT Payload
  """
  @gtt_type_SINGLE Constants.gtt_type_SINGLE()
  @gtt_type_OCO Constants.gtt_type_OCO()
  defp get_gtt_payload(
         trigger_type,
         tradingsymbol,
         exchange,
         [] = trigger_values,
         last_price,
         orders
       )
       when trigger_type in [@gtt_type_SINGLE, @gtt_type_OCO] do
    if trigger_type == @gtt_type_SINGLE and Enum.count(trigger_values) != 1 do
      raise "invalid `trigger_values` for single leg order type"
    end

    if trigger_type == @gtt_type_OCO and Enum.count(trigger_values) != 2 do
      raise "invalid `trigger_values` for OCO order type"
    end

    condition = %{
      exchange: exchange,
      tradingsymbol: tradingsymbol,
      trigger_values: trigger_values,
      last_price: last_price
    }

    gtt_orders =
      for o <- orders do
        for req <- ["transaction_type", "quantity", "order_type", "product", "price"] do
          if req not in o do
            raise "#{req} missing inside orders"
          end
        end

        %{
          exchange: exchange,
          tradingsymbol: tradingsymbol,
          transaction_type: o[:transaction_type],
          order_type: o[:order_type],
          quantity: o[:quantity],
          product: o[:product],
          price: o[:price]
        }
      end

    {condition, gtt_orders}
  end

  @doc """
  Place GTT order
  - `trigger_type` The type of GTT order(single/two-leg).
  - `tradingsymbol` Trading symbol of the instrument.
  - `exchange` Name of the exchange.
  - `trigger_values` Trigger values (json array).
  - `last_price` Last price of the instrument at the time of order placement.
  - `orders` JSON order array containing following fields
      - `transaction_type` BUY or SELL
      - `quantity` Quantity to transact
      - `price` The min or max price to execute the order at (for LIMIT orders)
  """
  def place_gtt(
        %Params{client: client},
        trigger_type,
        tradingsymbol,
        exchange,
        trigger_values,
        last_price,
        orders
      ) do
    {condition, gtt_orders} =
      get_gtt_payload(trigger_type, tradingsymbol, exchange, trigger_values, last_price, orders)

    client
    |> post(@routes[:gtt_place], %{
      condition: Jason.encode(condition),
      orders: Jason.encode(gtt_orders),
      type: trigger_type
    })
  end

  @doc """
  Place GTT order
  - `trigger_id` ID of GTT order we want to modify.
  - `trigger_type` The type of GTT order(single/two-leg).
  - `tradingsymbol` Trading symbol of the instrument.
  - `exchange` Name of the exchange.
  - `trigger_values` Trigger values (json array).
  - `last_price` Last price of the instrument at the time of order placement.
  - `orders` JSON order array containing following fields
      - `transaction_type` BUY or SELL
      - `quantity` Quantity to transact
      - `price` The min or max price to execute the order at (for LIMIT orders)
  """
  def modify_gtt(
        %Params{client: client},
        trigger_id,
        trigger_type,
        tradingsymbol,
        exchange,
        trigger_values,
        last_price,
        orders
      ) do
    {condition, gtt_orders} =
      get_gtt_payload(trigger_type, tradingsymbol, exchange, trigger_values, last_price, orders)

    client
    |> put(
      @routes[:gtt_modify],
      %{
        condition: Jason.encode(condition),
        orders: Jason.encode(gtt_orders),
        type: trigger_type
      },
      query: %{trigger_id: trigger_id}
    )
  end

  @doc """
  Delete a GTT order.
  """
  def delete_gtt(%Params{client: client}, trigger_id) do
    client
    |> delete(@routes[:gtt_delete], query: %{trigger_id: trigger_id})
  end
end
