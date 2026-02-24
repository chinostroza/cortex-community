defmodule CortexCommunity.Integration.HealthTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias CortexCommunity.IntegrationHelper, as: H

  setup_all do
    unless H.server_running?() do
      raise ExUnit.SkipError, message: "Server not running at localhost:4000 — start with `mix server` first"
    end

    :ok
  end

  describe "GET /api/health" do
    test "returns 200 with status field (no auth required)" do
      {:ok, resp} = H.get("/api/health")
      assert resp.status == 200
      # "ok" when workers available, "degraded" when no workers configured
      assert resp.body["status"] in ["ok", "degraded"]
    end
  end

  describe "GET /api/health/workers" do
    test "returns 200 with workers list (no auth required)" do
      {:ok, resp} = H.get("/api/health/workers")
      assert resp.status == 200
      assert is_list(resp.body["workers"])
    end
  end

  describe "GET /api/health/detailed" do
    test "returns 200 with detailed system info (no auth required)" do
      {:ok, resp} = H.get("/api/health/detailed")
      assert resp.status == 200
      # Response has "system" key with version, uptime, etc.
      assert Map.has_key?(resp.body, "system")
    end
  end

  describe "GET /api/stats" do
    test "returns 200 with stats (no auth required)" do
      {:ok, resp} = H.get("/api/stats")
      assert resp.status == 200
      assert is_map(resp.body)
    end
  end

  describe "GET /api/stats/providers" do
    test "returns 200 with per-provider stats (no auth required)" do
      {:ok, resp} = H.get("/api/stats/providers")
      assert resp.status == 200
      assert is_map(resp.body)
    end
  end
end
