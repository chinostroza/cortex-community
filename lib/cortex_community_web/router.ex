# lib/cortex_community_web/router.ex
defmodule CortexCommunityWeb.Router do
  use CortexCommunityWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug, origin: "*"
    plug CortexCommunityWeb.Plugs.RequestLogger
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CortexCommunityWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # API Routes
  scope "/api", CortexCommunityWeb do
    pipe_through :api

    # Core chat endpoint
    post "/chat", ChatController, :create
    post "/completions", ChatController, :create  # OpenAI compatible

    # Health and monitoring
    get "/health", HealthController, :index
    get "/health/workers", HealthController, :workers
    get "/health/detailed", HealthController, :detailed

    # Stats and metrics (basic)
    get "/stats", StatsController, :index
    get "/stats/providers", StatsController, :providers
  end

  # Browser routes for documentation and simple UI
  scope "/", CortexCommunityWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/dashboard", DashboardLive.Index, :index
    get "/docs", DocsController, :index
    get "/docs/api", DocsController, :api_reference
    get "/docs/quickstart", DocsController, :quickstart
  end

  # Development only routes
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dev/dashboard", metrics: CortexCommunityWeb.Telemetry
    end
  end
end

# lib/cortex_community_web/endpoint.ex
defmodule CortexCommunityWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :cortex_community

  # Serve at "/" the static files from "priv/static" directory
  plug Plug.Static,
    at: "/",
    from: :cortex_community,
    gzip: true,
    only: CortexCommunityWeb.static_paths()

  # Code reloading for development
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    length: 100_000_000  # 100MB for large prompts

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session,
    store: :cookie,
    key: "_cortex_community_key",
    signing_salt: "jF3kN9Qx",
    same_site: "Lax"

  plug CortexCommunityWeb.Router

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)
end
