defmodule CortexCommunityWeb.DocsController do
  use CortexCommunityWeb, :controller

  def index(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Documentation - Cortex Community</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 2rem; }
        .container { max-width: 800px; margin: 0 auto; }
        .card { background: white; padding: 2rem; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 2rem; }
        .link-button { display: inline-block; background: #667eea; color: white; padding: 1rem 2rem; border-radius: 6px; text-decoration: none; margin: 0.5rem 0; }
        .link-button:hover { background: #5a67d8; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>📚 Cortex Community Documentation</h1>
        
        <div class="card">
          <h2>API Reference</h2>
          <p>Complete API documentation with interactive examples.</p>
          <a href="/docs/api" class="link-button">View API Reference</a>
        </div>
        
        <div class="card">
          <h2>Quick Start</h2>
          <p>Get started with Cortex Community in minutes.</p>
          <a href="/docs/quickstart" class="link-button">Quick Start Guide</a>
        </div>
        
        <div class="card">
          <h2>GitHub Repository</h2>
          <p>Source code, issues, and contributions.</p>
          <a href="https://github.com/chinostroza/cortex_community" class="link-button" target="_blank">View on GitHub</a>
        </div>
      </div>
    </body>
    </html>
    """)
  end

  def api_reference(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>API Reference - Cortex Community</title>
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
        .header { background: #667eea; color: white; padding: 1rem; text-align: center; }
        .content { padding: 2rem; max-width: 1200px; margin: 0 auto; }
        .endpoint { background: #f8f9fa; border-left: 4px solid #667eea; padding: 1rem; margin: 1rem 0; border-radius: 4px; }
        .method { background: #28a745; color: white; padding: 0.2rem 0.5rem; border-radius: 3px; font-size: 0.8rem; }
        .method.post { background: #28a745; }
        .method.get { background: #007bff; }
        pre { background: #f1f3f4; padding: 1rem; border-radius: 4px; overflow-x: auto; }
        code { background: #f1f3f4; padding: 0.2rem 0.4rem; border-radius: 3px; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>🧠 Cortex Community API Reference</h1>
        <p>Multi-provider AI Gateway API Documentation</p>
      </div>
      
      <div class="content">
        <h2>Base URL</h2>
        <code>http://localhost:4000/api</code>
        
        <h2>Endpoints</h2>
        
        <div class="endpoint">
          <h3><span class="method post">POST</span> /chat</h3>
          <p>Send chat completion requests with streaming support</p>
          <h4>Request Body:</h4>
          <pre><code>{
            "messages": [
              {"role": "user", "content": "Hello!"}
            ],
            "stream": true,
            "model": "gpt-4",
            "temperature": 0.7,
            "max_tokens": 1000
          }</code></pre>
          <h4>Example:</h4>
          <pre><code>curl -X POST http://localhost:4000/api/chat \\
            -H "Content-Type: application/json" \\
            -d '{
              "messages": [{"role": "user", "content": "Hello!"}],
              "stream": false
            }'</code></pre>
        </div>
        
        <div class="endpoint">
          <h3><span class="method post">POST</span> /completions</h3>
          <p>OpenAI-compatible completions endpoint</p>
          <h4>Example:</h4>
          <pre><code>curl -X POST http://localhost:4000/api/completions \\
            -H "Content-Type: application/json" \\
            -d '{
              "messages": [{"role": "user", "content": "Write a haiku"}],
              "model": "any"
            }'</code></pre>
        </div>
        
        <div class="endpoint">
          <h3><span class="method get">GET</span> /health</h3>
          <p>Basic health check</p>
          <h4>Example:</h4>
          <pre><code>curl http://localhost:4000/api/health</code></pre>
        </div>
        
        <div class="endpoint">
          <h3><span class="method get">GET</span> /health/workers</h3>
          <p>Detailed worker status</p>
          <h4>Example:</h4>
          <pre><code>curl http://localhost:4000/api/health/workers</code></pre>
        </div>
        
        <div class="endpoint">
          <h3><span class="method get">GET</span> /stats</h3>
          <p>Usage statistics</p>
          <h4>Example:</h4>
          <pre><code>curl http://localhost:4000/api/stats</code></pre>
        </div>
        
        <div class="endpoint">
          <h3><span class="method get">GET</span> /stats/providers</h3>
          <p>Per-provider statistics</p>
          <h4>Example:</h4>
          <pre><code>curl http://localhost:4000/api/stats/providers</code></pre>
        </div>
      </div>
    </body>
    </html>
    """)
  end

  def quickstart(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Quick Start - Cortex Community</title>
      <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
        .header { background: #667eea; color: white; padding: 1rem; text-align: center; }
        .content { padding: 2rem; max-width: 1200px; margin: 0 auto; }
        pre { background: #f1f3f4; padding: 1rem; border-radius: 4px; overflow-x: auto; }
        .step { background: #f8f9fa; border-left: 4px solid #28a745; padding: 1rem; margin: 1rem 0; border-radius: 4px; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>🚀 Quick Start Guide</h1>
        <p>Get started with Cortex Community in minutes</p>
      </div>
      
      <div class="content">
        <div class="step">
          <h3>1. Test the Basic Health Check</h3>
          <pre><code>curl http://localhost:4000/api/health</code></pre>
        </div>
        
        <div class="step">
          <h3>2. Send Your First Chat Request</h3>
          <pre><code>curl -X POST http://localhost:4000/api/chat \\
            -H "Content-Type: application/json" \\
            -d '{
              "messages": [
                {"role": "user", "content": "Hello! Tell me a joke."}
              ],
              "stream": false
            }'</code></pre>
        </div>
        
        <div class="step">
          <h3>3. Try Streaming Responses</h3>
          <pre><code>curl -N -X POST http://localhost:4000/api/chat \\
            -H "Content-Type: application/json" \\
            -d '{
              "messages": [
                {"role": "user", "content": "Write a short poem about coding"}
              ],
              "stream": true
            }'</code></pre>
        </div>
        
        <div class="step">
          <h3>4. Check Worker Status</h3>
          <pre><code>curl http://localhost:4000/api/health/workers</code></pre>
        </div>
        
        <div class="step">
          <h3>5. Use with OpenAI SDK (Python)</h3>
          <pre><code>from openai import OpenAI

          client = OpenAI(
              base_url="http://localhost:4000/api",
              api_key="not-needed"
          )

          response = client.chat.completions.create(
              model="any-model",
              messages=[{"role": "user", "content": "Hello!"}]
          )

          print(response.choices[0].message.content)</code></pre>
        </div>
      </div>
    </body>
    </html>
    """)
  end
end