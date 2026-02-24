defmodule CortexCommunity.StatsCollectorTest do
  use ExUnit.Case, async: false

  alias CortexCommunity.StatsCollector

  # Reset state before each test to ensure isolation
  setup do
    StatsCollector.reset_stats()
    # get_stats/0 is a sync call — serves as barrier ensuring reset is applied
    StatsCollector.get_stats()
    :ok
  end

  # ---------------------------------------------------------------------------
  # get_stats/0 — basic structure
  # ---------------------------------------------------------------------------

  describe "get_stats/0" do
    test "returns a map with all required keys" do
      stats = StatsCollector.get_stats()

      assert Map.has_key?(stats, :requests_total)
      assert Map.has_key?(stats, :requests_completed)
      assert Map.has_key?(stats, :requests_failed)
      assert Map.has_key?(stats, :requests_no_workers)
      assert Map.has_key?(stats, :requests_active)
      assert Map.has_key?(stats, :average_duration)
      assert Map.has_key?(stats, :total_tokens)
      assert Map.has_key?(stats, :tokens_per_second)
      assert Map.has_key?(stats, :uptime_seconds)
    end

    test "initial stats are all zero after reset" do
      stats = StatsCollector.get_stats()

      assert stats[:requests_total] == 0
      assert stats[:requests_completed] == 0
      assert stats[:requests_failed] == 0
      assert stats[:requests_no_workers] == 0
      assert stats[:requests_active] == 0
      assert stats[:total_tokens] == 0
    end
  end

  # ---------------------------------------------------------------------------
  # track_request/1 — :started event
  # ---------------------------------------------------------------------------

  describe "track_request(:started)" do
    test "increments requests_total and requests_active" do
      StatsCollector.track_request(:started)
      stats = StatsCollector.get_stats()

      assert stats[:requests_total] == 1
      assert stats[:requests_active] == 1
    end

    test "multiple starts accumulate correctly" do
      StatsCollector.track_request(:started)
      StatsCollector.track_request(:started)
      StatsCollector.track_request(:started)
      stats = StatsCollector.get_stats()

      assert stats[:requests_total] == 3
      assert stats[:requests_active] == 3
    end
  end

  # ---------------------------------------------------------------------------
  # track_request/2 — :completed event
  # ---------------------------------------------------------------------------

  describe "track_request(:completed)" do
    test "increments completed and decrements active" do
      StatsCollector.track_request(:started)
      StatsCollector.track_request(:completed, %{duration: 200, tokens: 50})
      stats = StatsCollector.get_stats()

      assert stats[:requests_completed] == 1
      assert stats[:requests_active] == 0
    end

    test "accumulates total_tokens" do
      StatsCollector.track_request(:started)
      StatsCollector.track_request(:completed, %{duration: 100, tokens: 30})
      StatsCollector.track_request(:started)
      StatsCollector.track_request(:completed, %{duration: 200, tokens: 70})
      stats = StatsCollector.get_stats()

      assert stats[:total_tokens] == 100
    end

    test "average_duration is computed from completed requests" do
      StatsCollector.track_request(:started)
      StatsCollector.track_request(:completed, %{duration: 400, tokens: 0})
      StatsCollector.track_request(:started)
      StatsCollector.track_request(:completed, %{duration: 200, tokens: 0})
      stats = StatsCollector.get_stats()

      # avg = (400 + 200) / 2 = 300
      assert stats[:average_duration] == 300
    end

    test "active cannot go below zero" do
      # Complete without starting (active = 0)
      StatsCollector.track_request(:completed, %{duration: 0, tokens: 0})
      stats = StatsCollector.get_stats()

      assert stats[:requests_active] == 0
    end
  end

  # ---------------------------------------------------------------------------
  # track_request/1 — :failed event
  # ---------------------------------------------------------------------------

  describe "track_request(:failed)" do
    test "increments failed and decrements active" do
      StatsCollector.track_request(:started)
      StatsCollector.track_request(:failed)
      stats = StatsCollector.get_stats()

      assert stats[:requests_failed] == 1
      assert stats[:requests_active] == 0
    end
  end

  # ---------------------------------------------------------------------------
  # track_request/1 — :no_workers event
  # ---------------------------------------------------------------------------

  describe "track_request(:no_workers)" do
    test "increments no_workers and failed" do
      StatsCollector.track_request(:no_workers)
      stats = StatsCollector.get_stats()

      assert stats[:requests_no_workers] == 1
      assert stats[:requests_failed] == 1
    end
  end

  # ---------------------------------------------------------------------------
  # track_request/1 — :error event
  # ---------------------------------------------------------------------------

  describe "track_request(:error)" do
    test "increments failed and decrements active" do
      StatsCollector.track_request(:started)
      StatsCollector.track_request(:error)
      stats = StatsCollector.get_stats()

      assert stats[:requests_failed] == 1
      assert stats[:requests_active] == 0
    end
  end

  # ---------------------------------------------------------------------------
  # track_provider/3
  # ---------------------------------------------------------------------------

  describe "track_provider/3" do
    test "tracks :request event for a provider" do
      StatsCollector.track_provider("gemini-primary", :request, %{})
      provider_stats = StatsCollector.get_provider_stats()

      assert Map.has_key?(provider_stats, "gemini-primary")
      assert provider_stats["gemini-primary"].requests_total == 1
    end

    test "tracks :completed event with duration and tokens" do
      StatsCollector.track_provider("groq-primary", :request, %{})
      StatsCollector.track_provider("groq-primary", :completed, %{duration: 300, tokens: 60})
      provider_stats = StatsCollector.get_provider_stats()

      data = provider_stats["groq-primary"]
      assert data.requests_completed == 1
      assert data.total_tokens == 60
    end

    test "tracks :failed event" do
      StatsCollector.track_provider("gemini-primary", :request, %{})
      StatsCollector.track_provider("gemini-primary", :failed, %{})
      provider_stats = StatsCollector.get_provider_stats()

      assert provider_stats["gemini-primary"].requests_failed == 1
    end

    test "multiple providers tracked independently" do
      StatsCollector.track_provider("gemini-primary", :request, %{})
      StatsCollector.track_provider("groq-primary", :request, %{})
      StatsCollector.track_provider("groq-primary", :request, %{})
      provider_stats = StatsCollector.get_provider_stats()

      assert provider_stats["gemini-primary"].requests_total == 1
      assert provider_stats["groq-primary"].requests_total == 2
    end
  end

  # ---------------------------------------------------------------------------
  # get_provider_stats/0 — average_duration computed
  # ---------------------------------------------------------------------------

  describe "get_provider_stats/0" do
    test "average_duration is 0 when no completed requests" do
      StatsCollector.track_provider("gemini-primary", :request, %{})
      provider_stats = StatsCollector.get_provider_stats()

      assert provider_stats["gemini-primary"].average_duration == 0
    end

    test "average_duration is computed from completed requests" do
      StatsCollector.track_provider("gemini-primary", :completed, %{duration: 600, tokens: 0})
      StatsCollector.track_provider("gemini-primary", :completed, %{duration: 200, tokens: 0})
      provider_stats = StatsCollector.get_provider_stats()

      # avg = (600 + 200) / 2 = 400
      assert provider_stats["gemini-primary"].average_duration == 400
    end
  end

  # ---------------------------------------------------------------------------
  # get_hourly_stats/0
  # ---------------------------------------------------------------------------

  describe "get_hourly_stats/0" do
    test "returns hourly stats structure" do
      hourly = StatsCollector.get_hourly_stats()
      assert is_map(hourly)
    end
  end

  # ---------------------------------------------------------------------------
  # handle_info(:log_summary) — triggered via direct message send
  # This covers the periodic logging branches inside the GenServer.
  # ---------------------------------------------------------------------------

  describe "handle_info(:log_summary)" do
    test "handles log_summary with zero requests (no-op log)" do
      # requests_total == 0 → if branch is false, no Logger.info
      pid = Process.whereis(StatsCollector)
      send(pid, :log_summary)
      # Sync barrier: ensures the message was processed
      StatsCollector.get_stats()
    end

    test "handles log_summary with requests > 0 (logs summary)" do
      StatsCollector.track_request(:started)
      StatsCollector.track_request(:completed, %{duration: 100, tokens: 10})
      pid = Process.whereis(StatsCollector)
      send(pid, :log_summary)
      # Sync barrier
      stats = StatsCollector.get_stats()
      assert stats[:requests_total] > 0
    end
  end

  # ---------------------------------------------------------------------------
  # reset_stats/0
  # ---------------------------------------------------------------------------

  describe "reset_stats/0" do
    test "resets all counters to zero" do
      StatsCollector.track_request(:started)
      StatsCollector.track_request(:completed, %{duration: 100, tokens: 20})
      StatsCollector.track_provider("gemini-primary", :request, %{})

      StatsCollector.reset_stats()
      stats = StatsCollector.get_stats()

      assert stats[:requests_total] == 0
      assert stats[:requests_completed] == 0
      assert stats[:total_tokens] == 0
    end

    test "clears provider stats" do
      StatsCollector.track_provider("gemini-primary", :request, %{})
      StatsCollector.reset_stats()

      provider_stats = StatsCollector.get_provider_stats()
      assert provider_stats == %{}
    end
  end
end
