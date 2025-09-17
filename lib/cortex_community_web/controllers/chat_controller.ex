# lib/cortex_community_web/controllers/chat_controller.ex
defmodule CortexCommunityWeb.ChatController do
  use CortexCommunityWeb, :controller
  require Logger

  alias CortexCommunity.StatsCollector

  @doc """
  Main chat endpoint - handles streaming responses from AI providers
  """
  def create(conn, %{"messages" => messages} = params) when is_list(messages) do
    # Track request start
    start_time = System.monotonic_time(:millisecond)

    # Extract options
    opts = extract_options(params)

    # Log request
    Logger.info("Chat request received with #{length(messages)} messages")

    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("x-accel-buffering", "no")  # For nginx
    |> dispatch_and_stream(messages, opts, start_time)
  end

  def create(conn, %{"messages" => _}) do
    error_response(conn, 400, "Messages must be an array")
  end

  def create(conn, _params) do
    error_response(conn, 400, "Missing required field: messages")
  end

  # Private functions

  defp dispatch_and_stream(conn, messages, opts, start_time) do
    case CortexCore.chat(messages, opts) do
      {:ok, stream} ->
        # Track successful dispatch
        StatsCollector.track_request(:started)

        conn
        |> send_chunked(200)
        |> stream_response(stream, start_time)

      {:error, :no_workers_available} ->
        StatsCollector.track_request(:no_workers)
        error_response(conn, 503, "No AI workers available at this moment")

      {:error, {:all_workers_failed, details}} ->
        StatsCollector.track_request(:all_failed)
        Logger.error("All workers failed: #{inspect(details)}")

        conn
        |> put_status(500)
        |> json(%{
          error: true,
          message: "All AI providers failed",
          details: format_error_details(details),
          timestamp: DateTime.utc_now()
        })

      {:error, reason} ->
        StatsCollector.track_request(:error)
        Logger.error("Chat request failed: #{inspect(reason)}")
        error_response(conn, 500, "Internal server error")
    end
  end

  defp stream_response(conn, stream, start_time) do
    try do
      final_conn = Enum.reduce_while(stream, {conn, 0}, fn chunk, {acc_conn, token_count} ->
        case send_sse_chunk(acc_conn, chunk) do
          {:ok, new_conn} ->
            {:cont, {new_conn, token_count + estimate_tokens(chunk)}}
          {:error, _reason} ->
            {:halt, {acc_conn, token_count}}
        end
      end)
      |> case do
        {final_conn, token_count} ->
          # Send completion event
          duration = System.monotonic_time(:millisecond) - start_time

          _completion_data = %{
            event: "done",
            tokens: token_count,
            duration_ms: duration
          }

          {:ok, conn_with_done} = send_sse_chunk(final_conn, "[DONE]")

          # Track completion
          StatsCollector.track_request(:completed, %{
            duration: duration,
            tokens: token_count
          })

          Logger.info("Stream completed: #{token_count} tokens in #{duration}ms")

          conn_with_done
      end

      final_conn

    rescue
      error ->
        Logger.error("Stream processing error: #{inspect(error)}")
        StatsCollector.track_request(:stream_error)
        conn

    catch
      :exit, _ ->
        StatsCollector.track_request(:stream_exit)
        conn
      _, _ ->
        StatsCollector.track_request(:stream_error)
        conn
    end
  end

  defp send_sse_chunk(conn, "[DONE]") do
    case Plug.Conn.chunk(conn, "event: done\ndata: {\"done\": true}\n\n") do
      {:ok, conn} -> {:ok, conn}
      error -> error
    end
  end

  defp send_sse_chunk(conn, chunk) when is_binary(chunk) do
    # Format as SSE
    sse_data = "data: #{Jason.encode!(%{content: chunk})}\n\n"

    case Plug.Conn.chunk(conn, sse_data) do
      {:ok, conn} -> {:ok, conn}
      error -> error
    end
  end

  defp send_sse_chunk(conn, _), do: {:ok, conn}

  defp extract_options(params) do
    []
    |> maybe_add_option(:provider, params["provider"])
    |> maybe_add_option(:model, params["model"])
    |> maybe_add_option(:temperature, params["temperature"])
    |> maybe_add_option(:max_tokens, params["max_tokens"])
    |> maybe_add_option(:stream, params["stream"])
    |> maybe_add_option(:top_p, params["top_p"])
    |> maybe_add_option(:frequency_penalty, params["frequency_penalty"])
    |> maybe_add_option(:presence_penalty, params["presence_penalty"])
    |> maybe_add_option(:stop, params["stop"])
    |> maybe_add_option(:user, params["user"])
  end

  defp maybe_add_option(opts, _key, nil), do: opts
  defp maybe_add_option(opts, key, value) do
    Keyword.put(opts, key, value)
  end

  defp error_response(conn, status, message) do
    conn
    |> put_status(status)
    |> json(%{
      error: true,
      message: message,
      timestamp: DateTime.utc_now()
    })
  end

  defp format_error_details(details) when is_binary(details), do: details
  defp format_error_details(details) when is_list(details) do
    Enum.map(details, fn
      {provider, error} -> "#{provider}: #{error}"
      error -> to_string(error)
    end)
    |> Enum.join("; ")
  end
  defp format_error_details(details), do: inspect(details)

  defp estimate_tokens(text) when is_binary(text) do
    # Rough estimation: ~4 characters per token
    div(String.length(text), 4)
  end
  defp estimate_tokens(_), do: 0
end
