defmodule CortexCommunityWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use CortexCommunityWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint CortexCommunityWeb.Endpoint

      use CortexCommunityWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import CortexCommunityWeb.ConnCase
      import Mox
    end
  end

  setup _tags do
    Mox.verify_on_exit!()
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Returns a mock CortexUser struct for use in tests.
  """
  def user_fixture do
    %CortexCommunity.CortexUser{
      id: "00000000-0000-0000-0000-000000000001",
      username: "testuser",
      email: "test@example.com",
      name: "Test User"
    }
  end

  @doc """
  Puts a Bearer token header on the conn. Pair with a Users.Mock stub
  that returns {:ok, user_fixture()} for :authenticate_by_api_key.
  """
  def with_auth(conn) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer test-api-token")
  end
end
