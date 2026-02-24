defmodule CortexCommunityWeb.Plugs.AuthenticateApiKey do
  @moduledoc """
  Plug for authenticating requests using Cortex API keys.

  Expects an `Authorization` header in the format:
  - `Bearer ctx_...` (preferred)
  - `ctx_...` (also accepted)

  On successful authentication:
  - Assigns the authenticated user to `conn.assigns.cortex_user`

  On authentication failure:
  - Returns 401 Unauthorized

  ## Usage

  Add to router or controller:

      plug CortexCommunityWeb.Plugs.AuthenticateApiKey
  """

  import Plug.Conn
  require Logger

  @users Application.compile_env(:cortex_community, :users_module, CortexCommunity.Users)

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, api_key} <- extract_api_key(conn),
         {:ok, user} <- @users.authenticate_by_api_key(api_key) do
      # Authentication successful
      conn
      |> assign(:cortex_user, user)
      |> assign(:authenticated_via, :api_key)
    else
      {:error, :missing_authorization} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          401,
          Jason.encode!(%{
            error: "unauthorized",
            message: "Missing Authorization header. Use: Bearer ctx_..."
          })
        )
        |> halt()

      {:error, reason} ->
        # Invalid or expired API key
        Logger.warning("API key authentication failed: #{inspect(reason)}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          401,
          Jason.encode!(%{
            error: "unauthorized",
            message: format_error_message(reason)
          })
        )
        |> halt()
    end
  end

  # Extract API key from Authorization header
  defp extract_api_key(conn) do
    case get_req_header(conn, "authorization") do
      [] ->
        {:error, :missing_authorization}

      [auth_header | _] ->
        parse_auth_header(auth_header)
    end
  end

  # Parse different Authorization header formats
  defp parse_auth_header("Bearer " <> api_key), do: {:ok, String.trim(api_key)}
  defp parse_auth_header("bearer " <> api_key), do: {:ok, String.trim(api_key)}
  defp parse_auth_header("ctx_" <> _ = api_key), do: {:ok, String.trim(api_key)}
  defp parse_auth_header(_), do: {:error, :invalid_authorization_format}

  defp format_error_message(:invalid_api_key), do: "Invalid API key"
  defp format_error_message(:expired_api_key), do: "API key has expired"

  defp format_error_message(:invalid_authorization_format),
    do: "Invalid authorization header format"
end
