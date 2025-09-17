# lib/cortex_community_web/controllers/page_controller.ex
defmodule CortexCommunityWeb.PageController do
  use CortexCommunityWeb, :controller

  def home(conn, _params) do
    workers = CortexCore.list_workers()
    health = CortexCore.health_status()
    stats = CortexCommunity.StatsCollector.get_stats()

    # Render simple HTML page
    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Cortex Community - AI Gateway</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          max-width: 1200px;
          margin: 0 auto;
          padding: 2rem;
          background: #f5f5f5;
        }
        .header {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
          padding: 2rem;
          border-radius: 10px;
          margin-bottom: 2rem;
        }
        .stats-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
          gap: 1rem;
          margin-bottom: 2rem;
        }
        .stat-card {
          background: white;
          padding: 1.5rem;
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .stat-value {
          font-size: 2rem;
          font-weight: bold;
          color: #333;
        }
        .stat-label {
          color: #666;
          margin-top: 0.5rem;
        }
        .code-block {
          background: #1e1e1e;
          color: #d4d4d4;
          padding: 1rem;
          border-radius: 8px;
          overflow-x: auto;
          margin: 1rem 0;
        }
        .status-badge {
          display: inline-block;
          padding: 0.25rem 0.75rem;
          border-radius: 20px;
          font-size: 0.875rem;
          font-weight: 500;
        }
        .status-available {
          background: #10b981;
          color: white;
        }
        .status-unavailable {
          background: #ef4444;
          color: white;
        }
        .workers-list {
          background: white;
          padding: 1.5rem;
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .worker-item {
          display: flex;
          justify-content: space-between;
          padding: 0.75rem 0;
          border-bottom: 1px solid #eee;
        }
        .worker-item:last-child {
          border-bottom: none;
        }
        .link-button {
          display: inline-block;
          background: #667eea;
          color: white;
          padding: 0.75rem 1.5rem;
          border-radius: 6px;
          text-decoration: none;
          margin-right: 1rem;
        }
        .link-button:hover {
          background: #5a67d8;
        }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>🧠 Cortex Community</h1>
        <p>Open-source multi-provider AI gateway</p>
        <p>Version: #{Application.spec(:cortex_community, :vsn)}</p>
      </div>

      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-value">#{stats[:requests_total]}</div>
          <div class="stat-label">Total Requests</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">#{stats[:success_rate]}%</div>
          <div class="stat-label">Success Rate</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">#{length(workers)}</div>
          <div class="stat-label">Configured Workers</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">#{Enum.count(health, fn {_, s} -> s == :available end)}</div>
          <div class="stat-label">Available Workers</div>
        </div>
      </div>

      <div class="workers-list">
        <h2>Worker Status</h2>
        #{render_workers(workers, health)}
      </div>

      <h2>Quick Start</h2>
      <p>Send a request to the API:</p>
      <pre class="code-block">curl -N -X POST http://localhost:4000/api/chat \\
  -H "Content-Type: application/json" \\
  -d '{
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ]
  }'</pre>

      <h2>Resources</h2>
      <div>
        <a href="/docs/api" class="link-button">API Documentation</a>
        <a href="https://github.com/chinostroza/cortex_community" class="link-button">GitHub</a>
        <a href="/api/health" class="link-button">Health Check</a>
      </div>

      <div style="margin-top: 3rem; padding-top: 2rem; border-top: 1px solid #ddd; color: #666; text-align: center;">
        <p>
          Want advanced features? Check out
          <a href="https://cortexpro.ai" style="color: #667eea;">Cortex Pro</a>
          for dashboard, analytics, multi-tenancy, and more.
        </p>
      </div>
    </body>
    </html>
    """)
  end

  defp render_workers(workers, health) do
    workers
    |> Enum.map(fn worker ->
      status = Map.get(health, worker.name, :unknown)
      status_class = if status == :available, do: "status-available", else: "status-unavailable"
      status_text = status |> to_string() |> String.upcase()

      """
      <div class="worker-item">
        <div>
          <strong>#{worker.name}</strong>
          <span style="color: #666; margin-left: 1rem;">#{worker.type}</span>
        </div>
        <span class="status-badge #{status_class}">#{status_text}</span>
      </div>
      """
    end)
    |> Enum.join("")
  end
end

# lib/cortex_community_web/controllers/docs_controller.ex
defmodule CortexCommunityWeb.DocsController do
  use CortexCommunityWeb, :controller

  def api_reference(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>API Reference - Cortex Community</title>
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@stoplight/elements-dev-portal@1/dist/styles.min.css">
    </head>
    <body>
      <div id="api-docs"></div>
      <script src="https://cdn.jsdelivr.net/npm/@stoplight/elements-dev-portal@1/dist/web-components.min.js"></script>
      <script>
        // Embed OpenAPI spec
        const spec = #{Jason.encode!(openapi_spec())};
        const docsElement = document.getElementById('api-docs');
        docsElement.innerHTML = '<elements-api apiDescriptionDocument=' + JSON.stringify(spec) + ' router="hash" layout="sidebar"/>';
      </script>
    </body>
    </html>
    """)
  end

  defp openapi_spec do
    %{
      "openapi" => "3.0.0",
      "info" => %{
        "title" => "Cortex Community API",
        "version" => "1.0.0",
        "description" => "Multi-provider AI Gateway API"
      },
      "servers" => [
        %{"url" => "http://localhost:4000/api"}
      ],
      "paths" => %{
        "/chat" => %{
          "post" => %{
            "summary" => "Send chat completion request",
            "requestBody" => %{
              "required" => true,
              "content" => %{
                "application/json" => %{
                  "schema" => %{
                    "type" => "object",
                    "required" => ["messages"],
                    "properties" => %{
                      "messages" => %{
                        "type" => "array",
                        "items" => %{
                          "type" => "object",
                          "properties" => %{
                            "role" => %{"type" => "string", "enum" => ["user", "assistant", "system"]},
                            "content" => %{"type" => "string"}
                          }
                        }
                      },
                      "provider" => %{"type" => "string", "enum" => ["openai", "anthropic", "gemini", "groq", "ollama"]},
                      "model" => %{"type" => "string"},
                      "temperature" => %{"type" => "number", "minimum" => 0, "maximum" => 2},
                      "max_tokens" => %{"type" => "integer", "minimum" => 1}
                    }
                  }
                }
              }
            },
            "responses" => %{
              "200" => %{
                "description" => "Streaming response",
                "content" => %{
                  "text/event-stream" => %{
                    "schema" => %{"type" => "string"}
                  }
                }
              }
            }
          }
        },
        "/health" => %{
          "get" => %{
            "summary" => "Health check",
            "responses" => %{
              "200" => %{
                "description" => "System health status"
              }
            }
          }
        }
      }
    }
  end
end
