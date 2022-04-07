defmodule Zerodha.Params do
  import Zerodha.Constants

  defstruct debug: false,
            api_key: "testtsest",
            session_expiry_hook: nil,
            disable_ssl: false,
            access_token: "",
            proxies: [],
            root_url: default_root_url(),
            client: nil,
            response: nil,
            timeout: default_timeout()
end
