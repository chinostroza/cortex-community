# lib/cortex_community/stats_collector.ex
defmodule CortexCommunity.StatsCollector do
  @moduledoc """
  Simple in-memory stats collector for Cortex Community.
  Tracks basic metrics without external dependencies.
  """

  use GenServer
  require Logger

  # Reset daily to prevent memory bloat
  @stats_reset_interval :timer.hours(24)

  defstruct [
    :started_at,
    :requests_total,
    :requests_completed,
    :requests_failed,
    :requests_no_workers,
    :requests_active,
    :total_duration,
    :total_tokens,
    :provider_stats,
    :hourly_stats
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Track a request event
  """
  def track_request(event, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:track_request, event, metadata})
  end

  @doc """
  Track provider-specific event
  """
  def track_provider(provider, event, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:track_provider, provider, event, metadata})
  end

  @doc """
  Get current stats
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Get provider-specific stats
  """
  def get_provider_stats do
    GenServer.call(__MODULE__, :get_provider_stats)
  end

  @doc """
  Get hourly stats for the last 24 hours
  """
  def get_hourly_stats do
    GenServer.call(__MODULE__, :get_hourly_stats)
  end

  @doc """
  Reset all statistics
  """
  def reset_stats do
    GenServer.cast(__MODULE__, :reset_stats)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Schedule periodic cleanup
    Process.send_after(self(), :daily_reset, @stats_reset_interval)

    # Schedule periodic summary logging
    Process.send_after(self(), :log_summary, :timer.minutes(5))

    state = %__MODULE__{
      started_at: System.monotonic_time(:second),
      requests_total: 0,
      requests_completed: 0,
      requests_failed: 0,
      requests_no_workers: 0,
      requests_active: 0,
      total_duration: 0,
      total_tokens: 0,
      provider_stats: %{},
      hourly_stats: initialize_hourly_stats()
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:track_request, event, metadata}, state) do
    new_state =
      case event do
        :started ->
          %{
            state
            | requests_total: state.requests_total + 1,
              requests_active: state.requests_active + 1
          }
          |> update_hourly(:requests)

        :completed ->
          duration = Map.get(metadata, :duration, 0)
          tokens = Map.get(metadata, :tokens, 0)

          %{
            state
            | requests_completed: state.requests_completed + 1,
              requests_active: max(0, state.requests_active - 1),
              total_duration: state.total_duration + duration,
              total_tokens: state.total_tokens + tokens
          }
          |> update_hourly(:completed)

        :failed ->
          %{
            state
            | requests_failed: state.requests_failed + 1,
              requests_active: max(0, state.requests_active - 1)
          }
          |> update_hourly(:failed)

        :no_workers ->
          %{
            state
            | requests_no_workers: state.requests_no_workers + 1,
              requests_failed: state.requests_failed + 1
          }

        :error ->
          %{
            state
            | requests_failed: state.requests_failed + 1,
              requests_active: max(0, state.requests_active - 1)
          }

        _ ->
          state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:track_provider, provider, event, metadata}, state) do
    provider_data =
      Map.get(state.provider_stats, provider, %{
        requests_total: 0,
        requests_completed: 0,
        requests_failed: 0,
        total_duration: 0,
        total_tokens: 0,
        last_used: nil
      })

    updated_data =
      case event do
        :request ->
          %{
            provider_data
            | requests_total: provider_data.requests_total + 1,
              last_used: DateTime.utc_now()
          }

        :completed ->
          duration = Map.get(metadata, :duration, 0)
          tokens = Map.get(metadata, :tokens, 0)

          %{
            provider_data
            | requests_completed: provider_data.requests_completed + 1,
              total_duration: provider_data.total_duration + duration,
              total_tokens: provider_data.total_tokens + tokens
          }

        :failed ->
          %{provider_data | requests_failed: provider_data.requests_failed + 1}

        _ ->
          provider_data
      end

    new_state = %{state | provider_stats: Map.put(state.provider_stats, provider, updated_data)}

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:reset_stats, state) do
    new_state = %{
      state
      | requests_total: 0,
        requests_completed: 0,
        requests_failed: 0,
        requests_no_workers: 0,
        requests_active: 0,
        total_duration: 0,
        total_tokens: 0,
        provider_stats: %{},
        hourly_stats: initialize_hourly_stats()
    }

    Logger.info("Stats reset completed")
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    uptime = System.monotonic_time(:second) - state.started_at

    avg_duration =
      if state.requests_completed > 0 do
        div(state.total_duration, state.requests_completed)
      else
        0
      end

    tokens_per_second =
      if uptime > 0 do
        Float.round(state.total_tokens / uptime, 2)
      else
        0.0
      end

    stats = %{
      uptime_seconds: uptime,
      requests_total: state.requests_total,
      requests_completed: state.requests_completed,
      requests_failed: state.requests_failed,
      requests_no_workers: state.requests_no_workers,
      requests_active: state.requests_active,
      average_duration: avg_duration,
      total_tokens: state.total_tokens,
      tokens_per_second: tokens_per_second,
      success_rate: calculate_success_rate(state),
      error_rate: calculate_error_rate(state)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:get_provider_stats, _from, state) do
    provider_stats =
      Enum.map(state.provider_stats, fn {provider, data} ->
        avg_duration =
          if data.requests_completed > 0 do
            div(data.total_duration, data.requests_completed)
          else
            0
          end

        {provider, Map.put(data, :average_duration, avg_duration)}
      end)
      |> Enum.into(%{})

    {:reply, provider_stats, state}
  end

  @impl true
  def handle_call(:get_hourly_stats, _from, state) do
    {:reply, state.hourly_stats, state}
  end

  @impl true
  def handle_info(:daily_reset, state) do
    # Keep some historical data but reset counters
    Logger.info("Performing daily stats reset")

    new_state = %{
      state
      | requests_total: 0,
        requests_completed: 0,
        requests_failed: 0,
        requests_no_workers: 0,
        total_duration: 0,
        total_tokens: 0,
        hourly_stats: initialize_hourly_stats()
    }

    # Schedule next reset
    Process.send_after(self(), :daily_reset, @stats_reset_interval)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:log_summary, state) do
    if state.requests_total > 0 do
      Logger.info("""
      📊 Stats Summary:
      Requests: #{state.requests_total} total, #{state.requests_completed} completed, #{state.requests_failed} failed
      Active: #{state.requests_active}
      Tokens: #{state.total_tokens} total
      Success Rate: #{calculate_success_rate(state)}%
      """)
    end

    # Schedule next summary
    Process.send_after(self(), :log_summary, :timer.minutes(5))

    {:noreply, state}
  end

  # Private functions

  defp initialize_hourly_stats do
    # Initialize last 24 hours
    Enum.reduce(0..23, %{}, fn hour, acc ->
      Map.put(acc, hour, %{
        requests: 0,
        completed: 0,
        failed: 0,
        tokens: 0
      })
    end)
  end

  defp update_hourly(state, metric) do
    hour = DateTime.utc_now().hour
    hourly = Map.get(state.hourly_stats, hour, %{requests: 0, completed: 0, failed: 0, tokens: 0})

    updated_hourly =
      case metric do
        :requests -> %{hourly | requests: hourly.requests + 1}
        :completed -> %{hourly | completed: hourly.completed + 1}
        :failed -> %{hourly | failed: hourly.failed + 1}
      end

    %{state | hourly_stats: Map.put(state.hourly_stats, hour, updated_hourly)}
  end

  defp calculate_success_rate(%{requests_total: 0}), do: 100.0

  defp calculate_success_rate(%{requests_total: total, requests_completed: completed}) do
    Float.round(completed / total * 100, 2)
  end

  defp calculate_error_rate(%{requests_total: 0}), do: 0.0

  defp calculate_error_rate(%{requests_total: total, requests_failed: failed}) do
    Float.round(failed / total * 100, 2)
  end
end
