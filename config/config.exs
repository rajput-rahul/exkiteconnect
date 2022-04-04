use Mix.Config
config :tesla, adapter: Tesla.Adapter.Hackney

config :zerodha,
  base_url: "https://zerodha-sandbox.herokuapp.com"

# Move this url as ENV variable
