defmodule CortexCommunity.Clients.ClaudeOAuthClient do
  @moduledoc """
  HTTP client for making requests to Claude.ai using OAuth tokens.

  This client uses OAuth access tokens from Claude Code CLI (or similar)
  instead of API keys, allowing users to utilize their Claude Pro subscriptions.

  ## Usage

      iex> credentials = %{
        access_token: "sk-ant-...",
        refresh_token: "...",
        expires: 1234567890
      }
      iex> ClaudeOAuthClient.chat(messages, credentials, opts)
      {:ok, stream}
  """

  require Logger

  @anthropic_api_base "https://api.anthropic.com"
  @anthropic_version "2023-06-01"
  @user_agent "cortex-community/1.0"

  @doc """
  Makes a chat request to Claude.ai using OAuth credentials.

  Returns a stream of response chunks or an error tuple.
  """
  def chat(messages, credentials, opts \\ []) do
    access_token = Map.get(credentials, :access_token) || credentials["access_token"]

    if !access_token do
      {:error, :missing_access_token}
    else
      do_chat(messages, access_token, opts)
    end
  end

  defp do_chat(messages, access_token, opts) do

    # Build request parameters
    # Note: OAuth tokens use different model names than API keys
    model = Keyword.get(opts, :model, "claude-sonnet-4-5-20250929")
    max_tokens = Keyword.get(opts, :max_tokens, 4096)
    temperature = Keyword.get(opts, :temperature)
    stream = Keyword.get(opts, :stream, true)

    # Separate system messages from regular messages
    # Claude API requires system messages as a top-level parameter
    formatted_messages = format_messages(messages)
    {system_content, user_messages} = extract_system_message(formatted_messages)

    # Build request body (Anthropic Messages API format)
    body = %{
      model: model,
      max_tokens: max_tokens,
      messages: user_messages,
      stream: stream
    }

    # Add system parameter if we have system content
    body = if system_content, do: Map.put(body, :system, system_content), else: body

    # Add optional parameters
    body = if temperature, do: Map.put(body, :temperature, temperature), else: body

    # Make HTTP request
    # IMPORTANT: OAuth tokens require ?beta=true parameter
    url = "#{@anthropic_api_base}/v1/messages?beta=true"
    headers = build_headers(access_token, stream)

    Logger.debug("Making OAuth request to Claude.ai: model=#{model}, stream=#{stream}")

    case make_request(url, headers, body, stream) do
      {:ok, response} ->
        # For streaming, make_request already returns a Stream
        # For non-streaming, it returns the response body as a string
        if stream do
          {:ok, response}  # Already a Stream from create_stream/1
        else
          {:ok, parse_response(response)}  # Parse the full response
        end

      {:error, reason} ->
        Logger.error("Claude OAuth request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp build_headers(access_token, stream) do
    base_headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"},
      {"anthropic-version", @anthropic_version},
      {"anthropic-beta", "oauth-2025-04-20"},
      {"anthropic-dangerous-direct-browser-access", "true"},
      {"User-Agent", @user_agent}
    ]

    if stream do
      base_headers ++ [{"Accept", "text/event-stream"}]
    else
      base_headers ++ [{"Accept", "application/json"}]
    end
  end

  defp format_messages(messages) when is_list(messages) do
    Enum.map(messages, fn msg ->
      %{
        role: msg["role"] || msg[:role],
        content: msg["content"] || msg[:content]
      }
    end)
  end

  defp extract_system_message(messages) do
    # Find system messages and extract their content
    system_messages = Enum.filter(messages, fn msg -> msg.role == "system" end)
    user_messages = Enum.reject(messages, fn msg -> msg.role == "system" end)

    # Combine all system message content into one string
    system_content = case system_messages do
      [] -> nil
      msgs -> Enum.map_join(msgs, "\n\n", fn msg -> msg.content end)
    end

    {system_content, user_messages}
  end

  defp make_request(url, headers, body, stream) do
    json_body = Jason.encode!(body)

    if stream do
      # For streaming, use async request
      case HTTPoison.post(url, json_body, headers, stream_to: self(), async: :once, recv_timeout: 60_000) do
        {:ok, %HTTPoison.AsyncResponse{} = async_response} ->
          {:ok, create_stream(async_response)}

        {:error, %HTTPoison.Error{reason: reason}} ->
          {:error, {:request_failed, reason}}
      end
    else
      # For non-streaming, regular request
      case HTTPoison.post(url, json_body, headers, recv_timeout: 30_000) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          {:ok, body}

        {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
          Logger.error("Claude API error: HTTP #{status}, body: #{body}")
          {:error, {:http_error, status, body}}

        {:error, %HTTPoison.Error{reason: reason}} ->
          {:error, {:request_failed, reason}}
      end
    end
  end

  defp create_stream(%HTTPoison.AsyncResponse{id: _async_id} = async_response) do
    Stream.resource(
      fn -> {async_response, ""} end,
      fn {async_resp, buffer} ->
        receive do
          %HTTPoison.AsyncStatus{code: 200} ->
            HTTPoison.stream_next(async_resp)
            {[], {async_resp, buffer}}

          %HTTPoison.AsyncStatus{code: status} when status != 200 ->
            Logger.error("HTTP error: #{status}")
            # Continue to read error body
            HTTPoison.stream_next(async_resp)
            {[], {async_resp, buffer}}

          %HTTPoison.AsyncHeaders{} ->
            HTTPoison.stream_next(async_resp)
            {[], {async_resp, buffer}}

          %HTTPoison.AsyncChunk{chunk: chunk} ->
            HTTPoison.stream_next(async_resp)

            # Log chunk for debugging (only first 500 chars)
            if String.contains?(chunk, "error") do
              Logger.error("Received error chunk: #{String.slice(chunk, 0, 500)}")
            end

            # Append chunk to buffer
            new_buffer = buffer <> chunk

            # Try to extract complete SSE events from buffer
            {events, remaining} = extract_sse_events(new_buffer)

            # Parse events and extract text chunks
            text_chunks = Enum.flat_map(events, fn event ->
              case parse_sse_event(event) do
                {_type, %{"type" => "content_block_delta", "delta" => %{"text" => text}}} ->
                  [text]
                {_type, %{"delta" => %{"text" => text}}} ->
                  [text]
                {_type, %{"type" => "error"} = error_data} ->
                  Logger.error("Claude API error in stream: #{inspect(error_data)}")
                  []
                {_type, data} when is_map(data) ->
                  # Log any unexpected data for debugging
                  if Map.has_key?(data, "error") do
                    Logger.error("Error in SSE event: #{inspect(data)}")
                  end
                  []
                _ ->
                  []
              end
            end)

            {text_chunks, {async_resp, remaining}}

          %HTTPoison.AsyncEnd{} ->
            {:halt, {async_resp, buffer}}

        after
          30_000 -> {:halt, {async_resp, buffer}}
        end
      end,
      fn {_async_resp, _buffer} -> :ok end
    )
  end

  defp extract_sse_events(buffer) do
    # Split by double newline (SSE event separator)
    parts = String.split(buffer, "\n\n")

    # Last part might be incomplete, keep it in buffer
    {complete_events, remaining} = case parts do
      [] -> {[], ""}
      [single] -> {[], single}
      multiple ->
        # Get all parts except the last one
        {Enum.drop(multiple, -1), List.last(multiple)}
    end

    {complete_events |> Enum.reject(&(&1 == "")), remaining}
  end

  defp parse_sse_event(event_text) do
    # Parse SSE event format:
    # event: content_block_delta
    # data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
    lines = String.split(event_text, "\n")

    event_type = Enum.find_value(lines, fn line ->
      if String.starts_with?(line, "event:") do
        line |> String.replace_prefix("event:", "") |> String.trim()
      end
    end)

    data = Enum.find_value(lines, fn line ->
      if String.starts_with?(line, "data:") do
        json = line |> String.replace_prefix("data:", "") |> String.trim()
        case Jason.decode(json) do
          {:ok, decoded} -> decoded
          _ -> nil
        end
      end
    end)

    if data, do: {event_type, data}, else: nil
  end

  defp parse_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"content" => content}} ->
        # Extract text from content blocks
        text = Enum.map_join(content, "", fn
          %{"text" => text} -> text
          _ -> ""
        end)
        [text]

      {:ok, data} ->
        Logger.warning("Unexpected Claude API response format: #{inspect(data)}")
        []

      {:error, _} ->
        Logger.error("Failed to parse Claude API response")
        []
    end
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
        # No expiry info, assume valid
        true
    end
  end

  @doc """
  Refreshes an OAuth token using the refresh token.

  TODO: Implement token refresh with Anthropic's OAuth flow.
  """
  def refresh_token(_credentials) do
    {:error, :not_implemented}
  end
end
