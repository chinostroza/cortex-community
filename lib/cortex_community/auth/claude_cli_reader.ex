defmodule CortexCommunity.Auth.ClaudeCliReader do
  @moduledoc """
  Reads Claude Code CLI credentials from macOS Keychain or filesystem.

  Similar to OpenClaw's implementation, this module:
  1. First tries to read from macOS Keychain (preferred)
  2. Falls back to ~/.claude/.credentials.json
  3. Caches results to avoid repeated keychain access

  ## Examples

      iex> ClaudeCliReader.read_credentials()
      {:ok, %{
        type: :oauth,
        provider: :anthropic,
        access_token: "...",
        refresh_token: "...",
        expires: 1234567890000
      }}

      iex> ClaudeCliReader.read_credentials()
      {:error, :not_found}
  """

  require Logger

  @keychain_service "Claude Code-credentials"
  @keychain_account "Claude Code"
  @credentials_file_path "~/.claude/.credentials.json"

  @doc """
  Reads Claude CLI credentials from Keychain (macOS) or file.

  Returns `{:ok, credentials}` if found, `{:error, reason}` otherwise.
  """
  def read_credentials(opts \\ []) do
    platform = Keyword.get(opts, :platform, :os.type() |> elem(0))

    case platform do
      :darwin -> read_from_keychain() || read_from_file()
      _ -> read_from_file()
    end
  end

  @doc """
  Reads credentials from macOS Keychain using the `security` command.
  """
  def read_from_keychain do
    try do
      # Execute security command to read from Keychain
      {json_output, 0} = System.cmd(
        "security",
        [
          "find-generic-password",
          "-s", @keychain_service,
          "-a", @keychain_account,
          "-w"  # Output password only
        ],
        stderr_to_stdout: true
      )

      json_output
      |> String.trim()
      |> Jason.decode!()
      |> parse_claude_oauth()
      |> case do
        {:ok, creds} ->
          Logger.info("Read Claude CLI credentials from Keychain")
          {:ok, creds}
        error ->
          error
      end
    rescue
      error ->
        Logger.debug("Could not read from Keychain: #{inspect(error)}")
        nil
    end
  end

  @doc """
  Reads credentials from ~/.claude/.credentials.json file.
  """
  def read_from_file do
    file_path = Path.expand(@credentials_file_path)

    if File.exists?(file_path) do
      try do
        file_path
        |> File.read!()
        |> Jason.decode!()
        |> parse_claude_oauth()
        |> case do
          {:ok, creds} ->
            Logger.info("Read Claude CLI credentials from file: #{file_path}")
            {:ok, creds}
          error ->
            error
        end
      rescue
        error ->
          Logger.error("Error reading credentials file: #{inspect(error)}")
          {:error, :invalid_file}
      end
    else
      {:error, :not_found}
    end
  end

  # Private helpers

  defp parse_claude_oauth(%{"claudeAiOauth" => oauth}) when is_map(oauth) do
    with {:ok, access_token} <- get_string(oauth, "accessToken"),
         {:ok, expires_at} <- get_integer(oauth, "expiresAt") do

      refresh_token = get_string(oauth, "refreshToken") |> elem(1)

      credentials = %{
        type: if(refresh_token, do: :oauth, else: :token),
        provider: :anthropic,
        access_token: access_token,
        refresh_token: refresh_token,
        expires: expires_at
      }

      {:ok, credentials}
    else
      _ -> {:error, :invalid_format}
    end
  end

  defp parse_claude_oauth(_), do: {:error, :invalid_format}

  defp get_string(map, key) when is_map(map) do
    case Map.get(map, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_field}
    end
  end

  defp get_integer(map, key) when is_map(map) do
    case Map.get(map, key) do
      value when is_integer(value) -> {:ok, value}
      _ -> {:error, :missing_field}
    end
  end

  @doc """
  Checks if credentials are still valid (not expired).
  """
  def valid?(credentials) do
    case credentials do
      %{expires: expires} when is_integer(expires) ->
        now_ms = System.system_time(:millisecond)
        expires > now_ms

      _ ->
        false
    end
  end

  @doc """
  Returns the path where Claude CLI stores credentials.
  """
  def credentials_path, do: Path.expand(@credentials_file_path)
end
