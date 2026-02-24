defmodule CortexCommunity.Integration.SearchTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias CortexCommunity.IntegrationHelper, as: H

  setup_all do
    unless H.server_running?() do
      raise ExUnit.SkipError, message: "Server not running at localhost:4000 — start with `mix server` first"
    end

    {:ok, key: H.api_key()}
  end

  describe "POST /api/search" do
    test "returns 401 without auth" do
      {:ok, resp} = H.post("/api/search", %{query: "elixir programming"})
      assert resp.status == 401
    end

    test "returns search results for a query", %{key: key} do
      body = %{query: "Elixir programming language"}

      {:ok, resp} = H.post("/api/search", body, headers: H.auth_header(key))

      assert resp.status == 200
      assert resp.body["ok"] == true
      # Results are nested under "data" key
      data = resp.body["data"]
      assert is_map(data), "Expected data map in response: #{inspect(resp.body)}"
      assert is_list(data["results"]), "Expected results list in data: #{inspect(data)}"
    end

    test "returns 400 for missing query", %{key: key} do
      {:ok, resp} = H.post("/api/search", %{}, headers: H.auth_header(key))
      assert resp.status in [400, 422]
    end

    test "accepts optional provider param (uses specific search worker)", %{key: key} do
      body = %{
        query: "Phoenix Framework Elixir",
        provider: "duckduckgo-primary"
      }

      {:ok, resp} = H.post("/api/search", body, headers: H.auth_header(key))

      # duckduckgo is always configured (no API key needed)
      assert resp.status in [200, 404],
             "Expected 200 or 404, got #{resp.status}: #{inspect(resp.body)}"
    end
  end
end
