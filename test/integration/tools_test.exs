defmodule CortexCommunity.Integration.ToolsTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias CortexCommunity.IntegrationHelper, as: H

  @extract_tool %{
    "type" => "function",
    "function" => %{
      "name" => "extract_info",
      "description" => "Extract structured information from text",
      "parameters" => %{
        "type" => "object",
        "properties" => %{
          "topic" => %{"type" => "string", "description" => "Main topic"},
          "priority" => %{
            "type" => "string",
            "enum" => ["high", "medium", "low"],
            "description" => "Priority level"
          }
        },
        "required" => ["topic", "priority"]
      }
    }
  }

  setup_all do
    unless H.server_running?() do
      raise ExUnit.SkipError, message: "Server not running at localhost:4000 — start with `mix server` first"
    end

    {:ok, key: H.api_key()}
  end

  describe "POST /api/tools" do
    test "returns 401 without auth" do
      body = %{
        provider: "gemini-primary",
        messages: [%{role: "user", content: "test"}],
        tools: [@extract_tool]
      }

      {:ok, resp} = H.post("/api/tools", body)
      assert resp.status == 401
    end

    test "returns 400 when provider is missing", %{key: key} do
      body = %{
        messages: [%{role: "user", content: "test"}],
        tools: [@extract_tool]
      }

      {:ok, resp} = H.post("/api/tools", body, headers: H.auth_header(key))
      assert resp.status == 400
      # Response: {"error": true, "message": "Field 'provider' is required for tool use"}
      assert resp.body["message"] =~ "provider"
    end

    test "returns 404 for unknown provider", %{key: key} do
      body = %{
        provider: "nonexistent-provider",
        messages: [%{role: "user", content: "test"}],
        tools: [@extract_tool]
      }

      {:ok, resp} = H.post("/api/tools", body, headers: H.auth_header(key))
      assert resp.status == 404
    end

    test "returns tool_calls from gemini (if configured)", %{key: key} do
      body = %{
        provider: "gemini-primary",
        messages: [
          %{
            role: "user",
            content: "Analyze: Phoenix is a critical web framework for Elixir"
          }
        ],
        tools: [@extract_tool]
      }

      {:ok, resp} = H.post("/api/tools", body, headers: H.auth_header(key))

      case resp.status do
        200 ->
          assert resp.body["ok"] == true
          assert is_list(resp.body["tool_calls"])
          tool_calls = resp.body["tool_calls"]

          if length(tool_calls) > 0 do
            call = hd(tool_calls)
            assert Map.has_key?(call, "name") or Map.has_key?(call, :name)
            assert Map.has_key?(call, "arguments") or Map.has_key?(call, :arguments)
          end

        404 ->
          # gemini-primary not configured — acceptable
          :ok

        status when status in [429, 502, 503] ->
          # Provider rate limited or temporarily unavailable — acceptable
          :ok

        other ->
          flunk("Unexpected status #{other}: #{inspect(resp.body)}")
      end
    end

    test "returns tool_calls from groq with correct model (if configured)", %{key: key} do
      # Groq tool calling requires llama-3.3-70b-versatile
      body = %{
        provider: "groq-primary",
        model: "llama-3.3-70b-versatile",
        messages: [
          %{
            role: "user",
            content: "Analyze: Phoenix is a critical web framework for Elixir"
          }
        ],
        tools: [@extract_tool]
      }

      {:ok, resp} = H.post("/api/tools", body, headers: H.auth_header(key))

      case resp.status do
        200 ->
          assert resp.body["ok"] == true
          assert is_list(resp.body["tool_calls"])

        404 ->
          # groq-primary not configured — acceptable
          :ok

        status when status in [429, 502, 503] ->
          # Provider rate limited or temporarily unavailable — acceptable
          :ok

        other ->
          flunk("Unexpected status #{other}: #{inspect(resp.body)}")
      end
    end
  end
end
