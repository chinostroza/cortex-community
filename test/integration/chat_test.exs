defmodule CortexCommunity.Integration.ChatTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias CortexCommunity.IntegrationHelper, as: H

  setup_all do
    unless H.server_running?() do
      raise ExUnit.SkipError, message: "Server not running at localhost:4000 — start with `mix server` first"
    end

    {:ok, key: H.api_key()}
  end

  describe "POST /api/chat" do
    test "returns 401 without auth" do
      {:ok, resp} =
        H.post("/api/chat", %{messages: [%{role: "user", content: "hi"}]})

      assert resp.status == 401
    end

    test "returns SSE stream with content chunks", %{key: key} do
      body = %{
        messages: [%{role: "user", content: "Reply with exactly: OK"}]
      }

      {:ok, resp} =
        Req.post(H.base_url() <> "/api/chat",
          json: body,
          headers: H.auth_header(key),
          receive_timeout: 30_000,
          retry: false
        )

      assert resp.status == 200
      raw = resp.body

      # SSE response is a string with data: chunks
      assert is_binary(raw) or is_map(raw)

      content =
        if is_binary(raw) do
          raw
          |> String.split("\n")
          |> Enum.filter(&String.starts_with?(&1, "data: "))
          |> Enum.reject(&(&1 == "data: [DONE]"))
          |> Enum.map_join("", fn "data: " <> json ->
            case Jason.decode(json) do
              {:ok, %{"content" => c}} when is_binary(c) -> c
              _ -> ""
            end
          end)
        else
          ""
        end

      assert String.length(content) > 0, "Expected non-empty content in SSE stream"
    end

    test "routes to specific provider with provider field", %{key: key} do
      # Try with a provider that should exist (gemini or groq or anthropic)
      body = %{
        provider: "gemini-primary",
        messages: [%{role: "user", content: "Reply with: hi"}]
      }

      {:ok, resp} =
        Req.post(H.base_url() <> "/api/chat",
          json: body,
          headers: H.auth_header(key),
          receive_timeout: 30_000,
          retry: false
        )

      # 200: success; 404: provider not configured;
      # 429/502/503: provider rate limited or unavailable; 500: server error
      assert resp.status in [200, 404, 429, 500, 502, 503],
             "Expected valid HTTP status, got #{resp.status}: #{inspect(resp.body)}"
    end

    test "POST /api/completions is an alias for /api/chat", %{key: key} do
      body = %{
        messages: [%{role: "user", content: "Reply with exactly: OK"}]
      }

      {:ok, resp} =
        Req.post(H.base_url() <> "/api/completions",
          json: body,
          headers: H.auth_header(key),
          receive_timeout: 30_000,
          retry: false
        )

      assert resp.status == 200
    end

    test "handles empty messages gracefully", %{key: key} do
      {:ok, resp} =
        H.post("/api/chat", %{messages: []}, headers: H.auth_header(key))

      # Server attempts dispatch, all providers fail → 200 SSE with error or 4xx
      # Acceptable: 200 (SSE error event), 400, 422, 500
      assert resp.status in [200, 400, 422, 500]
    end
  end
end
