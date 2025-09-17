# lib/cortex_community_web/controllers/health_controller.ex
defmodule CortexCommunityWeb.HealthController do
  use CortexCommunityWeb, :controller

  @doc """
  Basic health check endpoint
  """
  def index(conn, _params) do
    health = CortexCore.health_status()
    available_workers = Enum.count(health, fn {_, status} -> status == :available end)
    total_workers = map_size(health)

    status = if available_workers > 0, do: "healthy", else: "degraded"

    json(conn, %{
      status: status,
      available_workers: available_workers,
      total_workers: total_workers,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Detailed health status of all workers
  """
  def workers(conn, _params) do
    health = CortexCore.health_status()
    workers = CortexCore.list_workers()

    worker_details = Enum.map(workers, fn worker ->
      %{
        name: worker.name,
        type: worker.type,
        priority: Map.get(worker, :priority, 100),
        status: Map.get(health, worker.name, :unknown),
        api_keys_count: Map.get(worker, :api_keys_count, 0)
      }
    end)

    json(conn, %{
      workers: worker_details,
      summary: %{
        total: length(worker_details),
        available: Enum.count(worker_details, & &1.status == :available),
        unavailable: Enum.count(worker_details, & &1.status == :unavailable),
        rate_limited: Enum.count(worker_details, & &1.status == :rate_limited)
      }
    })
  end

  @doc """
  Detailed system health including stats
  """
  def detailed(conn, _params) do
    health = CortexCore.health_status()
    stats = CortexCommunity.StatsCollector.get_stats()

    json(conn, %{
      health: health,
      stats: stats,
      system: %{
        version: Application.spec(:cortex_community, :vsn) |> to_string(),
        core_version: Application.spec(:cortex_core, :vsn) |> to_string(),
        uptime_seconds: stats[:uptime_seconds] || 0,
        memory_mb: div(:erlang.memory(:total), 1024 * 1024)
      }
    })
  end
end

# lib/cortex_community_web/controllers/stats_controller.ex
defmodule CortexCommunityWeb.StatsController do
  use CortexCommunityWeb, :controller

  alias CortexCommunity.StatsCollector

  @doc """
  Get general statistics
  """
  def index(conn, _params) do
    stats = StatsCollector.get_stats()

    json(conn, %{
      requests: %{
        total: stats[:requests_total] || 0,
        completed: stats[:requests_completed] || 0,
        failed: stats[:requests_failed] || 0,
        no_workers: stats[:requests_no_workers] || 0,
        active: stats[:requests_active] || 0
      },
      performance: %{
        average_duration_ms: stats[:average_duration] || 0,
        total_tokens: stats[:total_tokens] || 0,
        tokens_per_second: stats[:tokens_per_second] || 0
      },
      uptime: %{
        seconds: stats[:uptime_seconds] || 0,
        formatted: format_uptime(stats[:uptime_seconds] || 0)
      },
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Get per-provider statistics
  """
  def providers(conn, _params) do
    stats = StatsCollector.get_provider_stats()

    provider_details = Enum.map(stats, fn {provider, data} ->
      %{
        provider: provider,
        requests_total: data[:requests_total] || 0,
        requests_completed: data[:requests_completed] || 0,
        requests_failed: data[:requests_failed] || 0,
        total_tokens: data[:total_tokens] || 0,
        average_duration_ms: data[:average_duration] || 0,
        error_rate: calculate_error_rate(data),
        last_used: data[:last_used]
      }
    end)

    json(conn, %{
      providers: provider_details,
      summary: %{
        total_providers: length(provider_details),
        active_providers: Enum.count(provider_details, & &1.requests_total > 0)
      }
    })
  end

  # Private functions

  defp format_uptime(seconds) do
    days = div(seconds, 86400)
    hours = div(rem(seconds, 86400), 3600)
    minutes = div(rem(seconds, 3600), 60)

    parts = []
    parts = if days > 0, do: ["#{days}d" | parts], else: parts
    parts = if hours > 0, do: ["#{hours}h" | parts], else: parts
    parts = if minutes > 0, do: ["#{minutes}m" | parts], else: parts

    if parts == [], do: "< 1m", else: Enum.join(Enum.reverse(parts), " ")
  end

  defp calculate_error_rate(%{requests_total: 0}), do: 0.0
  defp calculate_error_rate(%{requests_total: total, requests_failed: failed}) do
    Float.round(failed / total * 100, 2)
  end
  defp calculate_error_rate(_), do: 0.0
end
