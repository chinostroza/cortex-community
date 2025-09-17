# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CortexCommunity is an open-source AI gateway built with Phoenix Framework that provides a unified interface to multiple AI providers (OpenAI, Anthropic, Google Gemini, Groq, Cohere, xAI) plus local AI support via Ollama.

## Common Development Commands

```bash
# Setup & Development
mix setup          # Install deps + setup assets
mix server         # Start Phoenix server (alias for phx.server)

# Testing & Quality
mix test           # Run tests
mix test test/path/to/test.exs  # Run specific test file
mix test.coverage  # Run tests with coverage
mix quality        # Format code and run credo
mix format         # Format code only
mix credo --strict # Run linter only

# Assets (for frontend changes)
mix assets.build   # Build CSS and JS
mix assets.deploy  # Build minified for production

# Release
mix release        # Build production release

# Docker
docker-compose up  # Start app with Ollama
```

## Architecture Overview

### Core Components

1. **Cortex Core Integration** (`cortex_core ~> 1.0.2`): The underlying AI routing engine that handles:
   - Provider management (OpenAI, Anthropic, Google, etc.)
   - Worker pool strategies (local_first, round_robin, least_used, random)
   - Health checks and failover
   - API key rotation

2. **Phoenix Web Layer** (`lib/cortex_community_web/`):
   - **Controllers**: Handle HTTP endpoints
     - `ChatController`: Main `/api/chat` endpoint with SSE streaming
     - `CompletionsController`: OpenAI-compatible `/api/completions`
     - `HealthController`: Health checks and worker status
     - `StatsController`: Usage statistics and metrics
   - **Router**: Defines API routes under `/api` scope

3. **Application Core** (`lib/cortex_community/`):
   - `Application`: OTP supervisor managing:
     - StatsCollector (GenServer for in-memory metrics)
     - Cortex Core supervisor
   - `StatsCollector`: Tracks request metrics, token usage, and provider statistics

### Key API Endpoints

- `/api/chat` - Main chat endpoint with SSE streaming support
- `/api/completions` - OpenAI-compatible completions endpoint
- `/api/health` - Basic health check
- `/api/health/workers` - Detailed worker status
- `/api/stats` - Request statistics
- `/api/stats/providers` - Per-provider metrics

### Environment Configuration

Key environment variables:
- `CORTEX_*` - Cortex Core configuration (worker pools, strategies, etc.)
- Provider API keys: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`, etc.
- `PORT` - Server port (default: 4000)
- `SECRET_KEY_BASE` - Phoenix secret key

### Testing Approach

- Tests are in `test/` directory
- Run specific tests with `mix test test/file_test.exs`
- Use `Phoenix.ConnTest` for controller tests
- Test SSE endpoints by checking response headers and chunks

### Development Guidelines

1. **Phoenix Conventions**: 
   - Follow standard Phoenix patterns
   - Use `Req` library for HTTP requests (already included)
   - Controllers return conn, not JSON directly

2. **Cortex Core Usage**:
   - Worker management is handled by Cortex Core
   - Use `Cortex.chat/2` for AI interactions
   - Health checks run automatically based on config

3. **Error Handling**:
   - Controllers handle Cortex errors gracefully
   - SSE streams include error events
   - Stats collector tracks failures

4. **Code Quality**:
   - Run `mix quality` before commits
   - Follow formatter rules in `.formatter.exs`
   - Credo enforces code standards