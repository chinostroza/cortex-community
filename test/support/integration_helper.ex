defmodule CortexCommunity.IntegrationHelper do
  @moduledoc false

  @base_url "http://localhost:4000"
  @timeout 30_000

  def base_url, do: @base_url

  def api_key do
    System.get_env("CORTEX_TEST_KEY") ||
      read_key_from_file() ||
      raise "No API key found. Set CORTEX_TEST_KEY or ensure /tmp/cortex_api_key.txt exists."
  end

  def server_running? do
    case Req.get(@base_url <> "/api/health", receive_timeout: 3_000, retry: false) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  def auth_header(key), do: [{"authorization", "Bearer #{key}"}]

  def get(path, opts \\ []) do
    headers = Keyword.get(opts, :headers, [])
    Req.get(@base_url <> path, headers: headers, receive_timeout: @timeout, retry: false)
  end

  def post(path, body, opts \\ []) do
    headers = Keyword.get(opts, :headers, [])

    Req.post(@base_url <> path,
      json: body,
      headers: headers,
      receive_timeout: @timeout,
      retry: false
    )
  end

  def get_sse(path, body, opts \\ []) do
    headers = Keyword.get(opts, :headers, [])
    url = @base_url <> path

    chunks = []

    case Finch.build(
           :post,
           url,
           [{"content-type", "application/json"} | headers],
           Jason.encode!(body)
         )
         |> Finch.stream(
           CortexCommunity.Finch,
           chunks,
           fn
             {:data, data}, acc -> [data | acc]
             _, acc -> acc
           end,
           receive_timeout: @timeout
         ) do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      {:error, reason, _} -> {:error, reason}
    end
  end

  defp read_key_from_file do
    case File.read("/tmp/cortex_api_key.txt") do
      {:ok, key} -> String.trim(key)
      _ -> nil
    end
  end
end
