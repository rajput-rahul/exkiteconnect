defmodule Zerodha.KiteConnect do
  @moduledoc """
  The Kite Connect API wrapper class_
    In production, you may initialise a single instance of this class per `api_key`_
  """

  alias Zerodha.Constants
  alias Zerodha.Params
  use Tesla

  @routes Constants.routes()

  @doc """
  Need to add default values for access token and api key from config file.
  """
  def init(
        api_key,
        access_token \\ nil,
        debug \\ false,
        disable_ssl \\ false,
        timeout \\ Constants.default_timeout()
      ) do
    %Params{
      access_token: access_token,
      api_key: api_key,
      debug: debug,
      disable_ssl: disable_ssl,
      timeout: timeout
    }
  end

  defp login_url(api_key) do
    "#{Constants.default_login_uri()}?api_key=#{api_key}&v=3"
  end

  def login(api_key) do
    get(login_url(api_key))
  end

  def setup(request_token, api_key, api_secret, root_url \\ Constants.default_root_url()) do
    init(api_key)
    |> generate_session(request_token, api_secret, root_url)

    # need to parse this result and apply the access token.
  end

  def generate_session(%Params{} = params, request_token, api_secret, root_url \\ Constants.default_root_url()) do
    checksum = generate_checksum(params.api_key <> request_token <> api_secret)

    access_token =
      params
      |> set_client(create_client())
      |> do_post(:api_token, %{
        api_key: params.api_key,
        checksum: checksum,
        request_token: request_token
      })
      |> extract_access_token()

    params
    |> set_access_token(access_token)
    |> setup_client_with_access_token(access_token, root_url)
  end

  def setup_client_with_access_token(%Params{api_key: api_key} = params, access_token, root_url) do
    middleware = [
      {Tesla.Middleware.BaseUrl, root_url},
      Tesla.Middleware.DecodeJson,
      Tesla.Middleware.EncodeFormUrlencoded,
      {Tesla.Middleware.Headers,
       [{"X-Kite-Version", 3}, {"Authorization", "token #{api_key}:#{access_token}"}]}
      #  , encode_content_type: "application/x-www-form-urlencoded"}
    ]

    params
    |> set_client(Tesla.client(middleware))
  end

  defp extract_access_token(%Tesla.Env{body: %{"data" => %{"access_token" => access_token}}}) do
    access_token
  end

  defp extract_access_token(resp) do
    raise "Invalid response returned. Either you have provided wrong root URL or `#{Constants.default_root_url()}` is not working. \n#{resp.body}"
  end

  defp generate_checksum(value) do
    :sha256
    |> :crypto.hash(value)
    |> Base.encode16()
    |> String.downcase()
  end

  def create_client() do
    middleware = [
      {Tesla.Middleware.BaseUrl,
       Application.get_env(:zerodha, :base_url, Constants.default_root_url())},
       Tesla.Middleware.DecodeJson,
       Tesla.Middleware.EncodeFormUrlencoded,
      {Tesla.Middleware.Headers, [{"X-Kite-Version", 3}]}
    ]

    Tesla.client(middleware)
  end

  defp do_get(%Params{client: client}, route, url_args \\ nil, query \\ %{}) do
    client
    |> get(format_url(route, url_args), query: query)
    |> case do
      {:ok, resp} -> resp
      {_, resp} -> resp
    end
  end

  defp do_post(%Params{client: client}, route, body_params, url_args \\ nil, query \\ %{}) do
    client
    |> post(format_url(route, url_args), body_params, query: query)
    |> case do
      {:ok, resp} -> resp
      {_, resp} -> resp
    end
  end

  defp do_put(%Params{client: client}, route, body_params, url_args \\ nil, query \\ %{}) do
    client
    |> put(format_url(route, url_args), body_params, query: query)
    |> case do
      {:ok, resp} -> resp
      {_, resp} -> resp
    end
  end

  defp do_delete(%Params{client: client}, route, url_args \\ nil, query \\ %{}) do
    client
    |> delete(format_url(route, url_args), query: query)
    |> case do
      {:ok, resp} -> resp
      {_, resp} -> resp
    end
  end

  # def format(route, url_args), do: format_url(route, url_args)

  defp format_url(route, url_args) when is_nil(url_args) do
    @routes[route]
  end

  defp format_url(route, url_args) do
    EEx.eval_string(@routes[route], url_args)
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

  @doc """
  Kill the session by invalidating the access token.
  - `access_token` to invalidate. Default is the active `access_token`.
  """
  def invalidate_access_token(
        %Params{
          access_token: access_token,
          api_key: api_key
        } = params
      ) do
    # client
    # |> delete(@routes[:api_token_invalidate], query: %{
    #   api_key: api_key,
    #   access_token: access_token
    # })

    do_delete(params, :api_token_invalidate, nil, %{
      api_key: api_key,
      access_token: access_token
    })
  end

  def invalidate_access_token(
        %Params{api_key: api_key} = params,
        access_token
      ) do
    do_delete(params, :api_token_invalidate, nil, %{
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

  def profile(%Params{} = params) do
    do_get(params, :user_profile)
  end

  @doc """
  Get account balance and cash margin details for a particular segment.
  """
  def margins(%Params{} = params) do
    do_get(params, :user_margins)
  end

  @doc """
  Get account balance and cash margin details for a particular segment.
  - `segment` is the trading segment (eg: equity or commodity)
  """
  def margins(%Params{} = params, segment) do
    do_get(params, :user_margins_segment, segment: segment)
  end

  @doc """
  Place an order
  """
  def place_order(
        %Params{} = params,
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

    do_post(params, :order_place, order_params, variety: variety)

    # We need to extract order_id from the response
  end

  @doc """
  Modifies an open order
  """
  def modify_order(
        %Params{} = params,
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

    do_put(params, :order_modify, order_params, variety: variety, order_id: order_id)

    # We need to extract order_id from the response
  end

  @doc """
  Cancel an order.
  """
  def cancel_order(%Params{} = params, variety, order_id, parent_order_id \\ nil) do
    do_delete(params, :order_cancel, [variety: variety, order_id: order_id], %{
      parent_order_id: parent_order_id
    })
  end

  @doc """
  Exit a BO/CO order.
  """
  def exit_order(%Params{} = params, variety, order_id, parent_order_id \\ nil) do
    cancel_order(params, variety, order_id, parent_order_id)
  end

  defp format_response, do: true
  # TODO: Still need to implement

  @doc """
  Get list of orders.
  """
  def orders(%Params{} = params) do
    do_get(params, :orders)
  end

  @doc """
  Get history of individual order.
  - `order_id` is the ID of the order to retrieve order history.
  """
  def order_history(%Params{} = params, order_id) do
    do_get(params, :orders_info, order_id: order_id)
  end

  @doc """
  Retrieve the list of trades executed (all or ones under a particular order).
  An order can be executed in tranches based on market conditions.
  These trades are individually recorded under an order.
  """
  def trades(%Params{} = params) do
    do_get(params, :trades)
  end

  @doc """
  Retrieve the list of trades executed for a particular order.
  - `order_id` is the ID of the order to retrieve trade history.
  """
  def order_trades(%Params{} = params, order_id) do
    do_get(params, :order_trades, order_id: order_id)
  end

  @doc """
  Retrieve the list of positions.
  """
  def positions(%Params{} = params) do
    do_get(params, :portfolio_positions)
  end

  @doc """
  Retrieve the list of equity holdings.
  """
  def holdings(%Params{} = params) do
    do_get(params, :portfolio_holdings)
  end

  @doc """
  Modify an open position's product type.
  """
  def convert_position(
        %Params{} = params,
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

    do_put(params, :portfolio_positions_convert, order_params)
  end

  @doc """
  Get all mutual fund orders.
  """
  def mf_orders(%Params{} = params) do
    do_get(params, :mf_orders)
  end

  @doc """
  Get individual mutual fund order info.
  """
  def mf_orders(%Params{} = params, order_id) do
    do_get(params, :mf_order_info, order_id: order_id)
  end

  @doc """
  Place a mutual fund order.
  """
  def place_mf_order(
        %Params{} = params,
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

    do_post(params, :mf_order_place, order_params)
  end

  @doc """
  Cancel a mutual fund order.
  """
  def cancel_mf_order(%Params{} = params, order_id) do
    do_delete(params, :mf_order_cancel, order_id: order_id)
  end

  @doc """
  Get list of all mutual fund SIP's.
  """
  def mf_sips(%Params{} = params) do
    do_get(params, :mf_sips)
  end

  @doc """
  Get individual mutual fund SIP info.
  """
  def mf_sips(%Params{} = params, sip_id) do
    do_get(params, :mf_sip_info, sip_id: sip_id)
  end

  @doc """
  Place a mutual fund SIP.
  """
  def place_mf_sip(
        %Params{} = params,
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

    do_post(params, :mf_sip_place, order_params)
  end

  @doc """
  Place a mutual fund SIP.
  """
  def modify_mf_sip(
        %Params{} = params,
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

    do_put(params, :mf_sip_modify, order_params, sip_id: sip_id)
  end

  @doc """
  Cancel a mutual fund SIP.
  """
  def cancel_mf_sip(%Params{} = params, sip_id) do
    do_delete(params, :mf_sip_cancel, sip_id: sip_id)
  end

  @doc """
  Get list of mutual fund holdings.
  """
  def mf_holdings(%Params{} = params) do
    do_get(params, :mf_holdings)
  end

  @doc """
  Get list of mutual fund instruments.
  """
  def mf_instruments(%Params{} = params) do
    do_get(params, :mf_instruments)
  end

  def instruments(%Params{} = params) do
    do_get(params, :market_instruments_all)
  end

  @doc """
  Retrieve the list of market instruments available to trade.

  Note that the results could be large, several hundred KBs in size,
  with tens of thousands of entries in the list.

  - `exchange` is specific exchange to fetch (Optional)
  """
  def instruments(%Params{} = params, exchange) do
    do_get(params, :market_instruments, exchange: exchange)
  end

  @doc """
  Retrieve quote for list of instruments.

  - `instruments` is a list of instruments, Instrument are in the format of `exchange:tradingsymbol`. For example NSE:INFY
  """
  def quote(%Params{} = params, [] = intruments_list) when is_list(intruments_list) do
    do_get(params, :market_quote, nil, %{i: intruments_list})

    # TODO: need to format data
  end

  @doc """
  Retrieve OHLC and market depth for list of instruments.

  - `instruments` is a list of instruments, Instrument are in the format of `exchange:tradingsymbol`. For example NSE:INFY
  """
  def ohlc(%Params{} = params, [] = intruments_list) when is_list(intruments_list) do
    do_get(params, :market_quote_ohlc, nil, %{i: intruments_list})
  end

  @doc """
  Retrieve last price for list of instruments.

  - `instruments` is a list of instruments, Instrument are in the format of `exchange:tradingsymbol`. For example NSE:INFY
  """
  def ltp(%Params{} = params, [] = intruments_list) when is_list(intruments_list) do
    do_get(params, :market_quote_ltp, nil, %{i: intruments_list})
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
        %Params{} = params,
        instrument_token,
        %DateTime{} = from_date,
        %DateTime{} = to_date,
        interval,
        continuous \\ false,
        oi \\ false
      ) do
    date_string_format = "%y-%m-%d %I:%M:%S"
    from_date_string = Calendar.strftime(from_date, date_string_format)
    to_date_string = Calendar.strftime(to_date, date_string_format)

    query_params = %{
      from: from_date_string,
      to: to_date_string,
      interval: interval,
      continuous: if(continuous, do: 1, else: 0),
      oi: if(oi, do: 1, else: 0)
    }

    do_get(
      params,
      :market_historical,
      [instrument_token: instrument_token, interval: interval],
      query_params
    )

    # TODO: Need to format this data as well
  end

  @doc """
  "Retrieve the buy/sell trigger range for Cover Orders.
  TODO: Need to implement
  """
  def trigger_range(), do: true

  @doc """
  Fetch list of GTT existing in an account.
  """
  def get_gtts(%Params{} = params) do
    do_get(params, :gtt)
  end

  @doc """
  Fetch list of a GTT.
  """
  def get_gtt(%Params{} = params, trigger_id) do
    do_get(params, :gtt_info, trigger_id: trigger_id)
  end

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
        %Params{} = params,
        trigger_type,
        tradingsymbol,
        exchange,
        trigger_values,
        last_price,
        orders
      ) do
    {condition, gtt_orders} =
      get_gtt_payload(trigger_type, tradingsymbol, exchange, trigger_values, last_price, orders)

    do_post(params, :gtt_place, %{
      condition: Jason.encode(condition),
      orders: Jason.encode(gtt_orders),
      type: trigger_type
    })

    # TODO: need to check json methods
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
        %Params{} = params,
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

    do_put(
      params,
      :gtt_modify,
      %{
        condition: Jason.encode(condition),
        orders: Jason.encode(gtt_orders),
        type: trigger_type
      },
      trigger_id: trigger_id
    )
  end

  @doc """
  Delete a GTT order.
  """
  def delete_gtt(%Params{} = params, trigger_id) do
    do_delete(params, :gtt_delete, trigger_id: trigger_id)
  end

  @doc """
  Calculate margins for requested order list considering the existing positions and open orders

  - `params` is list of orders to retrive margins detail
  """
  def order_margins(%Params{} = params, body_params) do
    do_post(params, :order_margins, body_params)

    # TODO: need to check for this is_json
  end

  @doc """
  Calculate total margins required for basket of orders including margin benefits
  - `params` is list of orders to fetch basket margin
  - `consider_positions` is a boolean to consider users positions
  - `mode` is margin response mode type. compact - Compact mode will only give the total margins
  """
  def basket_order_margins(
        %Params{} = params,
        body_params,
        consider_positions \\ true,
        mode \\ nil
      ) do
    do_post(params, :order_margins_basket, body_params, nil, %{
      consider_positions: consider_positions,
      mode: mode
    })
  end

  defp parse_instruments(data) do
    CSV.decode(data)
    # TODO need to implement this.
  end

  defp parse_mf_instruments(data), do: true
  # TODO need to implement this later after CSV learnings.
end
