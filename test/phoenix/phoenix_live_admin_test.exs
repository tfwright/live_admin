defmodule Phoenix.LiveAdminTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Phoenix.ConnTest

  @endpoint Phoenix.LiveAdminTest.Endpoint

  test "routes live view" do
    assert build_conn() |> get("/") |> html_response(200) =~ ~s|<title>Phoenix LiveAdmin</title>|
  end
end
