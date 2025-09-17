# Cortex Community

Open-source AI gateway powered by [Cortex Core](https://github.com/elixir-cortex/cortex_core). A unified interface to interact with multiple AI providers through a single API.

## Features

- **Multi-Provider Support**: OpenAI, Anthropic, Google Gemini, Groq, Cohere, xAI, and local models via Ollama
- **OpenAI-Compatible API**: Drop-in replacement for OpenAI SDK
- **Intelligent Load Balancing**: Multiple strategies (local_first, round_robin, least_used, random)
- **Automatic Failover**: Seamless switching between providers on failures
- **Health Monitoring**: Real-time provider health checks and status tracking
- **Usage Statistics**: Track requests, tokens, and costs across providers
- **Server-Sent Events**: Stream responses for real-time interactions
- **Docker Ready**: Easy deployment with Docker Compose including Ollama support

## Quick Start

### Using Docker (Recommended)

1. Clone the repository:
```bash
git clone https://github.com/chinostroza/cortex_community.git
cd cortex_community
```

2. Set up your API keys in `.env`:
```env
OPENAI_API_KEY=your-openai-key
ANTHROPIC_API_KEY=your-anthropic-key
GOOGLE_API_KEY=your-google-key
# Add other provider keys as needed
```

3. Start with Docker Compose:
```bash
docker-compose up
```

This will start both Cortex and Ollama (for local AI models).

### Manual Installation

Prerequisites:
- Elixir 1.15+
- Erlang/OTP 26+
- Node.js 18+ (for assets)

1. Install dependencies:
```bash
mix setup
```

2. Configure environment variables:
```bash
export OPENAI_API_KEY=your-openai-key
export ANTHROPIC_API_KEY=your-anthropic-key
# Add other provider keys
```

3. Start the server:
```bash
mix server
```

Visit http://localhost:4000 to see the application.

## API Usage

### Chat Endpoint (SSE)

Stream chat responses using Server-Sent Events:

```bash
curl -N -X POST http://localhost:4000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello!"}],
    "model": "gpt-4",
    "stream": true
  }'
```

### OpenAI-Compatible Endpoint

Use with any OpenAI SDK:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:4000/api",
    api_key="not-needed"  # API keys are configured server-side
)

response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

### Health Check

```bash
# Basic health
curl http://localhost:4000/api/health

# Detailed worker status
curl http://localhost:4000/api/health/workers
```

### Statistics

```bash
# Overall stats
curl http://localhost:4000/api/stats

# Per-provider stats
curl http://localhost:4000/api/stats/providers
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | 4000 |
| `SECRET_KEY_BASE` | Phoenix secret key | Auto-generated |
| `CORTEX_WORKER_POOL_STRATEGY` | Load balancing strategy | local_first |
| `CORTEX_HEALTH_CHECK_INTERVAL` | Health check interval (ms) | 30000 |
| `CORTEX_REQUEST_TIMEOUT` | Request timeout (ms) | 30000 |

### Provider API Keys

Set environment variables for the providers you want to use:

- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GOOGLE_API_KEY`
- `GROQ_API_KEY`
- `COHERE_API_KEY`
- `XAI_API_KEY`

### Worker Pool Strategies

Configure load balancing with `CORTEX_WORKER_POOL_STRATEGY`:

- `local_first` - Prefer local models (Ollama) when available
- `round_robin` - Distribute evenly across providers
- `least_used` - Route to least busy provider
- `random` - Random distribution

## Development

### Running Tests

```bash
# Run all tests
mix test

# Run specific test
mix test test/cortex_community_web/controllers/chat_controller_test.exs

# With coverage
mix test.coverage
```

### Code Quality

```bash
# Format and lint
mix quality

# Format only
mix format

# Lint only
mix credo --strict
```

### Building for Production

```bash
# Create release
mix release

# Deploy assets
mix assets.deploy
```

## Deployment

### Using Docker

The included `Dockerfile` creates a production-ready image:

```bash
# Build image
docker build -t cortex-community .

# Run container
docker run -p 4000:4000 \
  -e OPENAI_API_KEY=your-key \
  -e ANTHROPIC_API_KEY=your-key \
  cortex-community
```

### Using Releases

Build a release for deployment:

```bash
MIX_ENV=prod mix release
```

The release will be in `_build/prod/rel/cortex_community`.

### Health Checks

The application includes health check endpoints suitable for load balancers:

- `/api/health` - Returns 200 if service is up
- `/api/health/workers` - Returns detailed worker status

## Architecture

Cortex Community is built on:

- **[Cortex Core](https://github.com/elixir-cortex/cortex_core)** - AI provider management engine
- **Phoenix Framework** - Web framework and API layer
- **GenServer** - In-memory statistics tracking
- **Server-Sent Events** - Real-time streaming responses

See [CLAUDE.md](CLAUDE.md) for detailed architecture information.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests and quality checks (`mix test && mix quality`)
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

Built with [Cortex Core](https://github.com/elixir-cortex/cortex_core) - the Elixir AI toolkit.