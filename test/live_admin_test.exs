defmodule LiveAdminTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest

  @endpoint LiveAdminTest.Endpoint

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LiveAdminTest.Repo)

    %{conn: build_conn()}
  end

  describe "home page" do
    setup %{conn: conn} do
      %{response: conn |> get("/") |> html_response(200)}
    end

    test "routes live view", %{response: response} do
      assert response =~ ~s|<title>LiveAdmin</title>|
    end

    test "links to resource", %{response: response} do
      assert response |> Floki.find("a[href='/user']") |> Enum.any?()
    end
  end
end
