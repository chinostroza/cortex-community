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
