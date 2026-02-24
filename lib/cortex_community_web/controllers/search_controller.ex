defmodule CortexCommunityWeb.SearchController do
  use CortexCommunityWeb, :controller
  require Logger

  @cortex_core Application.compile_env(:cortex_community, :cortex_core, CortexCore)

  alias CortexCommunity.StatsCollector

  plug CortexCommunityWeb.Plugs.AuthenticateApiKey

  @doc """
  Ejecuta una búsqueda usando los workers de search disponibles.
  POST /api/search

  Body:
    - query (required): texto a buscar
    - provider (optional): worker específico ("tavily-primary", "brave-primary", etc.)
    - max_results (optional): número de resultados (default: 10)
    - search_depth (optional): "basic" | "advanced" (Tavily)
    - publication_type (optional): tipo de publicación para PubMed
  """
  def create(conn, %{"query" => query} = params) when is_binary(query) and query != "" do
    opts =
      []
      |> maybe_add(:provider, params["provider"])
      |> maybe_add(:max_results, params["max_results"])
      |> maybe_add(:search_depth, params["search_depth"])
      |> maybe_add(:publication_type, params["publication_type"])

    search_params = %{
      query: query,
      max_results: params["max_results"] || 10
    }

    Logger.info(
      "Search request: query=#{inspect(query)}, provider=#{inspect(params["provider"])}"
    )

    result = @cortex_core.call(:search, search_params, opts)

    case result do
      {:ok, data} ->
        StatsCollector.track_request(:completed, %{duration: 0, tokens: 0})
        json(conn, %{ok: true, data: data})

      {:error, :no_workers_available} ->
        conn
        |> put_status(503)
        |> json(%{ok: false, error: "No search workers available"})

      {:error, {:provider_not_found, name}} ->
        conn
        |> put_status(404)
        |> json(%{
          ok: false,
          error: "Worker '#{name}' not found. Check GET /api/models for available workers."
        })

      {:error, {:wrong_service_type, msg}} ->
        conn
        |> put_status(400)
        |> json(%{ok: false, error: msg})

      {:error, reason} ->
        Logger.error("Search failed: #{inspect(reason)}")

        conn
        |> put_status(500)
        |> json(%{ok: false, error: "Search failed", detail: inspect(reason)})
    end
  end

  def create(conn, %{"query" => _}) do
    conn
    |> put_status(400)
    |> json(%{ok: false, error: "Field 'query' must be a non-empty string"})
  end

  def create(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{ok: false, error: "Missing required field: query"})
  end

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)
end
