defmodule CortexCommunity.Integration.ModelsTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias CortexCommunity.IntegrationHelper, as: H

  setup_all do
    unless H.server_running?() do
      raise ExUnit.SkipError, message: "Server not running at localhost:4000 — start with `mix server` first"
    end

    {:ok, key: H.api_key()}
  end

  describe "GET /api/models" do
    test "returns 401 without auth" do
      {:ok, resp} = H.get("/api/models")
      assert resp.status == 401
    end

    test "returns workers grouped by type with total count", %{key: key} do
      {:ok, resp} = H.get("/api/models", headers: H.auth_header(key))
      assert resp.status == 200
      # Response has: total, llm (list), search (list), available (list)
      assert is_integer(resp.body["total"])
      assert resp.body["total"] > 0
      assert is_list(resp.body["llm"]) or is_list(resp.body["search"])
    end

    test "each worker entry has id, service, and how_to_use fields", %{key: key} do
      {:ok, resp} = H.get("/api/models", headers: H.auth_header(key))
      assert resp.status == 200

      all_workers = (resp.body["llm"] || []) ++ (resp.body["search"] || [])
      assert length(all_workers) > 0

      Enum.each(all_workers, fn worker ->
        assert is_binary(worker["id"]), "worker id should be a string: #{inspect(worker)}"
        assert is_binary(worker["service"]), "worker service should be a string: #{inspect(worker)}"
      end)
    end
  end
end
