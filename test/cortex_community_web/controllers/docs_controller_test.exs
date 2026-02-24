defmodule CortexCommunityWeb.DocsControllerTest do
  use CortexCommunityWeb.ConnCase

  describe "GET /docs" do
    test "returns HTML documentation index", %{conn: conn} do
      conn = get(conn, ~p"/docs")
      assert html_response(conn, 200) =~ "Documentation"
    end
  end

  describe "GET /docs/api" do
    test "returns API reference documentation", %{conn: conn} do
      conn = get(conn, ~p"/docs/api")
      assert html_response(conn, 200) =~ "API"
    end
  end

  describe "GET /docs/quickstart" do
    test "returns quickstart guide", %{conn: conn} do
      conn = get(conn, ~p"/docs/quickstart")
      assert html_response(conn, 200) =~ "Quick"
    end
  end
end
