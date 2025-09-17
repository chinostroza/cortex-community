defmodule CortexCommunityWeb.Plugs.RequestLogger do
  @behaviour Plug
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time(:millisecond)

    Plug.Conn.register_before_send(conn, fn conn ->
      duration = System.monotonic_time(:millisecond) - start_time
      
      Logger.info(
        "#{conn.method} #{conn.request_path} - #{conn.status} (#{duration}ms)"
      )
      
      conn
    end)
  end
end