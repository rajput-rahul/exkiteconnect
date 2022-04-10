use Mix.Config
config :tesla, adapter: Tesla.Adapter.Hackney

config :zerodha,
  api_key: System.get_env("API_KEY"),
  api_secret: System.get_env("API_SECRET"),
  base_url: "https://api.kite.trade"

# config :trading,

# Move this url as ENV variable
