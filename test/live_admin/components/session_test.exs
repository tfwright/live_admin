defmodule LiveAdmin.Components.SessionTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest

  @endpoint LiveAdminTest.Endpoint

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LiveAdminTest.Repo)

    Mox.stub_with(LiveAdminTest.MockSession, LiveAdminTest.StubSession)

    %{conn: build_conn()}
  end

  describe "session page" do
    setup %{conn: conn} do
      %{response: conn |> get("/session") |> html_response(200)}
    end

    test "routes live view", %{response: response} do
      assert response =~ ~s|<title>LiveAdmin</title>|
    end
  end
end
