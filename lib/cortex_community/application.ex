# lib/cortex_community/application.ex
defmodule CortexCommunity.Application do
  @moduledoc """
  Main application supervisor for Cortex Community.
  Starts all necessary processes including the web endpoint and Cortex Core.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Print startup banner
    print_banner()

    # Configure Cortex Core from environment
    _cortex_config = configure_cortex()

    children = [
      # Start the Ecto repository
      CortexCommunity.Repo,

      # Start Telemetry supervisor
      CortexCommunityWeb.Telemetry,

      # Start CortexCore supervisor
      %{
        id: CortexCore,
        start: {CortexCore, :start_link, [[
          strategy: String.to_atom(System.get_env("WORKER_POOL_STRATEGY", "local_first")),
          health_check_interval: String.to_integer(System.get_env("HEALTH_CHECK_INTERVAL", "30")) * 1000
        ]]},
        type: :supervisor
      },

      # Start simple stats collector
      CortexCommunity.StatsCollector,

      # Start the PubSub system
      {Phoenix.PubSub, name: CortexCommunity.PubSub},

      # Start Finch for HTTP client
      {Finch, name: CortexCommunity.Finch},

      # Start the Endpoint (last)
      CortexCommunityWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: CortexCommunity.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("🚀 Cortex Community started successfully!")
        print_status()
        {:ok, pid}

      error ->
        Logger.error("Failed to start Cortex Community: #{inspect(error)}")
        error
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    CortexCommunityWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp configure_cortex do
    # Read configuration from environment
    strategy = case System.get_env("WORKER_POOL_STRATEGY", "local_first") do
      "round_robin" -> :round_robin
      "least_used" -> :least_used
      "random" -> :random
      _ -> :local_first
    end

    health_check = case System.get_env("HEALTH_CHECK_INTERVAL", "30") do
      "0" -> 0
      interval -> String.to_integer(interval) * 1000
    end

    [
      strategy: strategy,
      health_check_interval: health_check
    ]
  end

  defp print_banner do
    banner = """

    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║      ░█████╗░░█████╗░██████╗░████████╗███████╗██╗░░██╗  ║
    ║      ██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝╚██╗██╔╝  ║
    ║      ██║░░╚═╝██║░░██║██████╔╝░░░██║░░░█████╗░░░╚███╔╝░  ║
    ║      ██║░░██╗██║░░██║██╔══██╗░░░██║░░░██╔══╝░░░██╔██╗░  ║
    ║      ╚█████╔╝╚█████╔╝██║░░██║░░░██║░░░███████╗██╔╝╚██╗  ║
    ║      ░╚════╝░░╚════╝░╚═╝░░╚═╝░░░╚═╝░░░╚══════╝╚═╝░░╚═╝  ║
    ║                                                           ║
    ║               Community Edition v#{version()}            ║
    ║                  Powered by Cortex Core                  ║
    ╚═══════════════════════════════════════════════════════════╝
    """

    IO.puts(banner)
  end

  defp print_status do
    workers = CortexCore.list_workers()

    IO.puts("\n📊 System Status:")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("🔧 Workers configured: #{length(workers)}")

    Enum.each(workers, fn worker ->
      IO.puts("   • #{worker.name} (#{worker.type})")
    end)

    port = Application.get_env(:cortex_community, CortexCommunityWeb.Endpoint)[:http][:port]
    IO.puts("\n🌐 API available at: http://localhost:#{port}")
    IO.puts("📚 Documentation at: http://localhost:#{port}/docs")
    IO.puts("💓 Health check at: http://localhost:#{port}/health")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
  end

  defp version do
    Application.spec(:cortex_community, :vsn) |> to_string()
  end
end
