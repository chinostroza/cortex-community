# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :cortex_community,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :cortex_community, CortexCommunityWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: CortexCommunityWeb.ErrorHTML, json: CortexCommunityWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CortexCommunity.PubSub,
  live_view: [signing_salt: "dyJ/To5f"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  cortex_community: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  cortex_community: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure CortexCore
config :cortex_core,
  workers: [
    # Example workers - uncomment and add your API keys
    # %{
    #   name: "openai-main",
    #   type: :openai,
    #   api_key: System.get_env("OPENAI_API_KEY")
    # },
    # %{
    #   name: "anthropic-main", 
    #   type: :anthropic,
    #   api_key: System.get_env("ANTHROPIC_API_KEY")
    # }
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
