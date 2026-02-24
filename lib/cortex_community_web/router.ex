# lib/cortex_community_web/router.ex
defmodule CortexCommunityWeb.Router do
  use CortexCommunityWeb, :router

  pipeline :api do
    plug :accepts, ["json"]

    plug CORSPlug,
      origin: [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:4000",
        "http://localhost:4200",
        "http://localhost:5173",
        "http://localhost:8080",
        "http://localhost:8000",
        "http://127.0.0.1",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080"
      ],
      methods: ["GET", "POST", "OPTIONS"],
      headers: ["Authorization", "Content-Type", "Accept"]

    plug CortexCommunityWeb.Plugs.RequestLogger
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CortexCommunityWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'"
    }
  end

  # API Routes
  scope "/api", CortexCommunityWeb do
    pipe_through :api

    # Core chat endpoint
    post "/chat", ChatController, :create
    # OpenAI compatible
    post "/completions", ChatController, :create

    # Search endpoint
    post "/search", SearchController, :create

    # Tool use / function calling endpoint
    post "/tools", ToolsController, :create

    # Available models + context windows
    get "/models", ModelsController, :index

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
