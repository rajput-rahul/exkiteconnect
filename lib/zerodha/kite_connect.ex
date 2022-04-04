defmodule Zerodha.KiteConnect do
  @moduledoc """
  The Kite Connect API wrapper class_
    In production, you may initialise a single instance of this class per `api_key`_
  """

  @default_root_uri "https://zerodha-sandbox.herokuapp.com"
  @default_login_uri "https://kite_trade/connect/login"
  @default_timeout 7000

  # Constants
  # products
  @product_MIS "MIS"
  @product_CNC "CNC"
  @product_NRML "NRML"
  @product_CO "CO"
  @product_BO "BO"

  # order types
  @order_type_market "MARKET"
  @order_type_limit "LIMIT"
  @order_type_slm "SL-M"
  @order_type_sl "SL"

  # Varities
  @variety_REGULAR "regular"
  @variety_BO "bo"
  @variety_CO "co"
  @variety_AMO "amo"

  # transaction type
  @transaction_type_buy "BUY"
  @transaction_type_sell "SELL"

  # validity
  @validity_day "DAY"
  @validity_IOC "IOC"

  # position type
  @position_type_day "day"
  @position_type_overnight "overnight"

  # exchanges
  @exchange_NSE "NSE"
  @exchange_BSE "BSE"
  @exchange_NFO "NFO"
  @exchange_CDS "CDS"
  @exchange_BFO "BFO"
  @exchange_MCX "MCX"
  @exchange_BCD "BCD"

  # Margins segments
  @margin_equity "equity"
  @margin_commodity "commodity"

  # status constants
  @status_complete "COMPLETE"
  @status_rejected "REJECTED"
  @status_cancelled "CANCELLED"

  # gtt order type
  @gtt_type_OCO "two-leg"
  @gtt_type_SINGLE "single"

  # gtt order status
  @gtt_status_active "active"
  @gtt_status_triggered "triggered"
  @gtt_status_disabled "disabled"
  @gtt_status_expired "expired"
  @gtt_status_cancelled "cancelled"
  @gtt_status_rejected "rejected"
  @gtt_status_deleted "deleted"

  @routes %{
    api_token: "/session/token",
    api_token_invalidate: "/session/token",
    api_token_renew: "/session/refresh_token",
    user_profile: "/user/profile",
    user_margins: "/user/margins",
    user_margins_segment: "/user/margins/{segment}",
    orders: "/orders",
    trades: "/trades",
    order_info: "/orders/{order_id}",
    order_place: "/orders/{variety}",
    order_modify: "/orders/{variety}/{order_id}",
    order_cancel: "/orders/{variety}/{order_id}",
    order_trades: "/orders/{order_id}/trades",
    portfolio_positions: "/portfolio/positions",
    portfolio_holdings: "/portfolio/holdings",
    portfolio_positions_convert: "/portfolio/positions",

    # MF api endpoints
    mf_orders: "/mf/orders",
    mf_order_info: "/mf/orders/{order_id}",
    mf_order_place: "/mf/orders",
    mf_order_cancel: "/mf/orders/{order_id}",
    mf_sips: "/mf/sips",
    mf_sip_info: "/mf/sips/{sip_id}",
    mf_sip_place: "/mf/sips",
    mf_sip_modify: "/mf/sips/{sip_id}",
    mf_sip_cancel: "/mf/sips/{sip_id}",
    mf_holdings: "/mf/holdings",
    mf_instruments: "/mf/instruments",
    market_instruments_all: "/instruments",
    market_instruments: "/instruments/{exchange}",
    market_margins: "/margins/{segment}",
    market_historical: "/instruments/historical/{instrument_token}/{interval}",
    market_trigger_range: "/instruments/trigger_range/{transaction_type}",
    market_quote: "/quote",
    market_quote_ohlc: "/quote/ohlc",
    market_quote_ltp: "/quote/ltp",

    # gtt endpoints
    gtt: "/gtt/triggers",
    gtt_place: "/gtt/triggers",
    gtt_info: "/gtt/triggers/{trigger_id}",
    gtt_modify: "/gtt/triggers/{trigger_id}",
    gtt_delete: "/gtt/triggers/{trigger_id}",

    # Margin computation endpoints
    order_margins: "/margins/orders",
    order_margins_basket: "/margins/basket"
  }

  use Tesla

  def orders(client) do
    get(client, @routes[:orders])
  end

  def generate_session()

  def client(_token) do
    middleware = [
      {Tesla.Middleware.BaseUrl, Application.get_env(:tesla, :base_url, @default_root_uri)},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end
end
