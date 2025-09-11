# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :tideland_ledger,
  ecto_repos: [TidelandLedger.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures our new endpoint
config :tideland_ledger, LedgerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: LedgerWeb.ErrorHTML, json: LedgerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TidelandLedger.PubSub,
  live_view: [signing_salt: "zQxN3Kl9"]

# Configures the endpoint
config :tideland_ledger, TidelandLedgerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: TidelandLedgerWeb.ErrorHTML, json: TidelandLedgerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: TidelandLedger.PubSub,
  live_view: [signing_salt: "zQxN3Kl9"]

# Mailer configuration disabled for now - no email functionality implemented yet
# config :tideland_ledger, TidelandLedger.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
