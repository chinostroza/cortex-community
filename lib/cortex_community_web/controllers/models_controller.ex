defmodule CortexCommunityWeb.ModelsController do
  use CortexCommunityWeb, :controller

  @cortex_core Application.compile_env(:cortex_community, :cortex_core, CortexCore)

  plug CortexCommunityWeb.Plugs.AuthenticateApiKey

  # Ventanas de contexto conocidas por modelo (input/output en tokens)
  @context_windows %{
    # Anthropic Claude
    "claude-sonnet-4-20250514" => %{input: 200_000, output: 64_000},
    "claude-3.7-sonnet" => %{input: 200_000, output: 64_000},
    "claude-3.5-haiku" => %{input: 200_000, output: 8_192},
    # Google Gemini 3
    "gemini-3-flash-preview" => %{input: 1_000_000, output: 65_536},
    # Google Gemini 2.5 (legacy / referencia)
    "gemini-2.5-flash" => %{input: 1_048_576, output: 65_535},
    "gemini-2.5-flash-lite" => %{input: 1_048_576, output: 65_535},
    # Groq / Meta LLaMA
    "llama-3.1-8b-instant" => %{input: 128_000, output: 32_768},
    "llama-3.3-70b-versatile" => %{input: 128_000, output: 32_768},
    # OpenAI
    "gpt-4o" => %{input: 128_000, output: 16_384},
    "gpt-5" => %{input: 128_000, output: 16_384},
    # xAI Grok
    "grok-code-fast-1" => %{input: 131_072, output: 16_384},
    # Cohere
    "command-light" => %{input: 4_096, output: 4_096},
    "command-r-plus" => %{input: 128_000, output: 4_096}
  }

  # list_workers() already returns info maps (result of info/1), not structs
  @search_types [:search]

  @doc """
  Lista todos los workers disponibles, su ventana de contexto y cómo usarlos.
  GET /api/models
  """
  def index(conn, _params) do
    health = @cortex_core.health_status()
    # @cortex_core.list_workers() returns info maps, not structs
    workers = @cortex_core.list_workers()

    models =
      Enum.map(workers, fn info ->
        name = info[:name] || info["name"]
        type = info[:type] || info["type"]
        model_name = info[:default_model] || info[:model] || info["model"]
        ctx = if model_name, do: Map.get(@context_windows, to_string(model_name)), else: nil
        service = if type in @search_types, do: :search, else: :llm

        %{
          id: name,
          service: service,
          provider_type: type,
          model: model_name,
          status: Map.get(health, name, :unknown),
          context_window: ctx,
          capabilities: info[:capabilities] || [],
          how_to_use: usage_instructions(name, service)
        }
      end)

    llm_models = Enum.filter(models, &(&1.service == :llm))
    search_models = Enum.filter(models, &(&1.service == :search))

    json(conn, %{
      llm: llm_models,
      search: search_models,
      total: length(models),
      available: Enum.count(models, &(&1.status == :available))
    })
  end

  defp usage_instructions(worker_name, :llm) do
    %{
      endpoint: "POST /api/chat",
      note: "Use 'provider' to target this model. Without 'provider', uses best available.",
      example: %{
        provider: worker_name,
        messages: [%{role: "user", content: "your message"}]
      }
    }
  end

  defp usage_instructions(worker_name, :search) do
    %{
      endpoint: "POST /api/search",
      note:
        "Use 'provider' to target this search engine. Without 'provider', uses best available.",
      example: %{
        provider: worker_name,
        query: "your search query",
        max_results: 10
      }
    }
  end
end
