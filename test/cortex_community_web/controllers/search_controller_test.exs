defmodule CortexCommunityWeb.SearchControllerTest do
  use CortexCommunityWeb.ConnCase

  # Realistic fixture based on actual Tavily API response via Cortex
  @search_result_fixture %{
    results: [
      %{
        title: "Elixir Programming Language",
        url: "https://elixir-lang.org",
        content: "Elixir is a dynamic, functional language for scalable applications.",
        score: 0.95
      },
      %{
        title: "Elixir Forum 2025",
        url: "https://elixirforum.com",
        content: "Community discussions about Elixir in 2025.",
        score: 0.87
      }
    ],
    query: "elixir 2025"
  }

  # ---------------------------------------------------------------------------
  # Authentication — no mock setup needed
  # ---------------------------------------------------------------------------

  describe "POST /api/search — authentication" do
    test "returns 401 when Authorization header is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/search", %{"query" => "elixir"})
      assert json = json_response(conn, 401)
      assert json["error"] == "unauthorized"
    end

    test "returns 401 with unrecognized authorization scheme", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Token some-random-value")
        |> post(~p"/api/search", %{"query" => "elixir"})

      assert json_response(conn, 401)
    end
  end

  # ---------------------------------------------------------------------------
  # Input validation (auth stubbed)
  # ---------------------------------------------------------------------------

  describe "POST /api/search — input validation" do
    setup do
      stub(CortexCommunity.Users.Mock, :authenticate_by_api_key, fn _key ->
        {:ok, user_fixture()}
      end)

      :ok
    end

    test "returns 400 when query field is missing", %{conn: conn} do
      conn =
        conn
        |> with_auth()
        |> post(~p"/api/search", %{})

      assert json = json_response(conn, 400)
      assert json["error"] =~ "query"
    end

    test "returns 400 when query is an empty string", %{conn: conn} do
      conn =
        conn
        |> with_auth()
        |> post(~p"/api/search", %{"query" => ""})

      assert json = json_response(conn, 400)
      assert json["error"] =~ "non-empty"
    end
  end

  # ---------------------------------------------------------------------------
  # Success path
  # ---------------------------------------------------------------------------

  describe "POST /api/search — success" do
    setup do
      stub(CortexCommunity.Users.Mock, :authenticate_by_api_key, fn _key ->
        {:ok, user_fixture()}
      end)

      :ok
    end

    test "returns search results on success (any available provider)", %{conn: conn} do
      expect(CortexCore.Mock, :call, fn :search, _params, _opts ->
        {:ok, @search_result_fixture}
      end)

      conn =
        conn
        |> with_auth()
        |> post(~p"/api/search", %{"query" => "elixir 2025"})

      assert json = json_response(conn, 200)
      assert json["ok"] == true
      assert Map.has_key?(json, "data")
    end

    test "passes explicit provider to cortex_core", %{conn: conn} do
      expect(CortexCore.Mock, :call, fn :search, _params, opts ->
        assert Keyword.get(opts, :provider) == "tavily-primary"
        {:ok, @search_result_fixture}
      end)

      conn
      |> with_auth()
      |> post(~p"/api/search", %{"query" => "elixir 2025", "provider" => "tavily-primary"})
    end
  end

  # ---------------------------------------------------------------------------
  # Error paths
  # ---------------------------------------------------------------------------

  describe "POST /api/search — error handling" do
    setup do
      stub(CortexCommunity.Users.Mock, :authenticate_by_api_key, fn _key ->
        {:ok, user_fixture()}
      end)

      :ok
    end

    test "returns 503 when no search workers available", %{conn: conn} do
      expect(CortexCore.Mock, :call, fn :search, _params, _opts ->
        {:error, :no_workers_available}
      end)

      conn =
        conn
        |> with_auth()
        |> post(~p"/api/search", %{"query" => "elixir"})

      assert json = json_response(conn, 503)
      assert json["ok"] == false
      assert json["error"] =~ "workers"
    end

    test "returns 404 when specified provider is not found", %{conn: conn} do
      expect(CortexCore.Mock, :call, fn :search, _params, _opts ->
        {:error, {:provider_not_found, "pubmed-primary"}}
      end)

      conn =
        conn
        |> with_auth()
        |> post(~p"/api/search", %{"query" => "elixir", "provider" => "pubmed-primary"})

      assert json = json_response(conn, 404)
      assert json["ok"] == false
      assert json["error"] =~ "pubmed-primary"
    end

    test "returns 400 when wrong service type is requested", %{conn: conn} do
      expect(CortexCore.Mock, :call, fn :search, _params, _opts ->
        {:error, {:wrong_service_type, "Worker 'gemini-primary' is not a search worker"}}
      end)

      conn =
        conn
        |> with_auth()
        |> post(~p"/api/search", %{"query" => "elixir", "provider" => "gemini-primary"})

      assert json = json_response(conn, 400)
      assert json["ok"] == false
    end

    test "returns 500 on unexpected error", %{conn: conn} do
      expect(CortexCore.Mock, :call, fn :search, _params, _opts ->
        {:error, :network_timeout}
      end)

      conn =
        conn
        |> with_auth()
        |> post(~p"/api/search", %{"query" => "elixir"})

      assert json = json_response(conn, 500)
      assert json["ok"] == false
    end
  end
end
