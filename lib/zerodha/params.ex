defmodule Zerodha.Params do
  import Zerodha.Constants

  defstruct debug: false,
            api_key: "testtsest",
            session_expiry_hook: nil,
            # We don't need it
            disable_ssl: false,
            access_token: "",
            # We don't need it
            proxies: [],
            client: nil,
            # We don't need it
            response: nil,
            # We don't need it
            timeout: default_timeout()
end
