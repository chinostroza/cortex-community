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
        # Configure workers synchronously to ensure they're ready on startup
        Task.start(fn ->
          :timer.sleep(500)
          try do
            CortexCore.Workers.Supervisor.configure_initial_workers(CortexCore.Workers.Registry)
          rescue
            e -> Logger.error("Failed to configure workers: #{inspect(e)}")
          end
        end)
        # Auto-setup default user and OAuth credentials on startup
        Task.start(fn ->
          :timer.sleep(1000)
          auto_setup()
        end)
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

  defp auto_setup do
    alias CortexCommunity.{Users, Credentials, Auth.ClaudeCliReader}

    # Crear usuario default si no existe
    user = case Users.get_user_by_username("default") do
      nil ->
        case Users.create_user(%{username: "default", name: "Default User"}) do
          {:ok, u} -> u
          _ -> nil
        end
      existing -> existing
    end

    if user do
      # Generar API key y guardarlo en /tmp
      api_key_value = get_api_key_value(user.id)

      # Leer y guardar credenciales OAuth del Claude Code CLI
      oauth_ok = case ClaudeCliReader.read_credentials() do
        {:ok, creds} ->
          case Credentials.store_credentials(user.id, "anthropic_cli", creds) do
            {:ok, _} ->
              sub = Map.get(creds, :subscription_type, "desconocida")
              Logger.info("✅ Credenciales OAuth cargadas (suscripción: #{sub})")
              true
            _ -> false
          end
        {:error, reason} ->
          Logger.warning("⚠️  No se encontraron credenciales OAuth: #{inspect(reason)}. Abre Claude Code CLI para autenticarte.")
          false
      end

      # Validar que el gateway responde correctamente
      if oauth_ok do
        validate_gateway(api_key_value)
      end
    end
  end

  defp get_api_key_value(user_id) do
    case CortexCommunity.Users.create_api_key(user_id, %{name: "auto"}) do
      {:ok, api_key} ->
        File.write("/tmp/cortex_api_key.txt", api_key.key)
        Logger.info("🔑 API key listo: #{api_key.key}")
        api_key.key
      _ -> nil
    end
  end

  defp validate_gateway(nil), do: :ok
  defp validate_gateway(api_key) do
    port = Application.get_env(:cortex_community, CortexCommunityWeb.Endpoint)[:http][:port] || 4000
    url = "http://localhost:#{port}/api/chat"

    body = Jason.encode!(%{
      messages: [%{role: "user", content: "responde solo: ok"}],
      model: "claude-sonnet-4-5-20250929",
      stream: false
    })

    case Req.post(url,
      headers: [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}],
      body: body,
      receive_timeout: 30_000
    ) do
      {:ok, %{status: status}} when status in 200..299 ->
        IO.puts("\n✅ Cortex listo — OAuth con Claude Max funcionando")
        IO.puts("   API Key: #{api_key}\n")
      {:ok, %{status: status, body: body}} ->
        Logger.warning("⚠️  Validación falló (HTTP #{status}): #{inspect(body)}")
      {:error, reason} ->
        Logger.warning("⚠️  No se pudo validar el gateway: #{inspect(reason)}")
    end
  end

  defp version do
    Application.spec(:cortex_community, :vsn) |> to_string()
  end
end
