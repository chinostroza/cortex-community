defmodule CortexCommunity.Clients.ClaudeWebClient do
  @moduledoc """
  HTTP client for making requests to claude.ai web API using OAuth tokens.

  This client uses the internal claude.ai web API endpoints (not the public
  Anthropic API) which accept OAuth tokens and work with Claude Pro/Max subscriptions.

  ## Usage

      iex> credentials = %{
        access_token: "sk-ant-oat01-...",
        refresh_token: "sk-ant-ort01-...",
        expires: 1234567890
      }
      iex> ClaudeWebClient.chat(messages, credentials, opts)
      {:ok, stream}
  """

  require Logger

  @claude_web_base "https://claude.ai"
  @user_agent "cortex-community/1.0"

  @doc """
  Makes a chat request to claude.ai using OAuth credentials.

  This will be updated once we capture the actual endpoint format.
  """
  def chat(messages, credentials, opts \\ []) do
    access_token = Map.get(credentials, :access_token) || credentials["access_token"]

    if access_token do
      do_chat(messages, access_token, opts)
    else
      {:error, :missing_access_token}
    end
  end

  defp do_chat(_messages, _access_token, opts) do
    # Update with actual endpoint from mitmproxy capture
    # Expected format based on research:
    # POST https://claude.ai/api/organizations/{org_id}/chat_conversations/{conversation_id}/completion

    model = Keyword.get(opts, :model, "claude-3-5-sonnet-20241022")

    Logger.debug("Making request to claude.ai web API: model=#{model}")

    # This will be implemented once we capture the actual traffic
    {:error, :not_yet_implemented}
  end

  @doc """
  Gets the organization ID for the authenticated user.

  This is typically needed before making chat requests.
  """
  def get_organization_id(access_token) do
    url = "#{@claude_web_base}/api/organizations"
    headers = build_headers(access_token)

    case HTTPoison.get(url, headers, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, orgs} when is_list(orgs) -> extract_org_id(orgs)
          {:ok, %{"uuid" => org_id}} -> {:ok, org_id}
          _ -> {:error, :invalid_response}
        end

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp extract_org_id([%{"uuid" => org_id} | _]), do: {:ok, org_id}
  defp extract_org_id([_ | _]), do: {:error, :no_organization_found}
  defp extract_org_id([]), do: {:error, :no_organization_found}

  defp build_headers(access_token) do
    [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"},
      {"User-Agent", @user_agent},
      {"Accept", "application/json"}
    ]
  end

  @doc """
  Checks if OAuth credentials are still valid (not expired).
  """
  def credentials_valid?(credentials) do
    case credentials do
      %{expires: expires} when is_integer(expires) ->
        now_ms = System.system_time(:millisecond)
        expires > now_ms

      %{"expires" => expires} when is_integer(expires) ->
        now_ms = System.system_time(:millisecond)
        expires > now_ms

      _ ->
        true
    end
  end
end
