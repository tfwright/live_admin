defmodule Phoenix.LiveAdminTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveAdminTest.{Repo, User}

  @endpoint Phoenix.LiveAdminTest.Endpoint

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Phoenix.LiveAdminTest.Repo)

    %{conn: build_conn()}
  end

  describe "home page" do
    setup %{conn: conn} do
      %{response: conn |> get("/") |> html_response(200)}
    end

    test "routes live view", %{response: response} do
      assert response =~ ~s|<title>Phoenix LiveAdmin</title>|
    end

    test "links to resource", %{response: response} do
      assert response |> Floki.find("a[href='/live_admin_test_user']") |> Enum.any?()
    end
  end

  describe "resource page" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/live_admin_test_user")
      %{view: view}
    end

    test "links to new form", %{view: view} do
      assert {_, {:live_redirect, %{to: "/live_admin_test_user/new"}}} =
               view
               |> element("a[href='/live_admin_test_user/new'")
               |> render_click()
    end
  end

  describe "new resource page" do
    setup %{conn: conn} do
      {:ok, view, html} = live(conn, "/live_admin_test_user/new")
      %{response: html, view: view}
    end

    test "includes castable form field", %{response: response} do
      assert response |> Floki.find("input[name='params[name]']") |> Enum.any?()
    end

    test "includes embed form field", %{response: response} do
      assert response |> Floki.find("input[name='params[settings][some_option]']") |> Enum.any?()
    end

    test "handles form change", %{view: view} do
      assert view |> element("form") |> render_change()
    end

    test "persists all form changes", %{view: view} do
      response =
        view
        |> element("form")
        |> render_change(%{
          "params" => %{"name" => "test name", "settings" => %{"some_option" => "test option"}}
        })

      assert response =~ "test option"
      assert response =~ "test name"
    end

    test "creates user on form submit", %{view: view} do
      {_, {:live_redirect, %{to: "/live_admin_test_user"}}} =
        view
        |> element("form")
        |> render_submit(%{name: "test", settings: %{some_option: "test"}})

      assert [%{}] = Repo.all(User)
    end
  end

  describe "edit resource page" do
    setup %{conn: conn} do
      user = Repo.insert!(%User{})
      {:ok, view, html} = live(conn, "/live_admin_test_user/edit/#{user.id}")
      %{response: html, view: view}
    end

    test "handles form submit", %{view: view} do
      {_, {:live_redirect, %{to: "/live_admin_test_user"}}} =
        view
        |> element("form")
        |> render_submit(%{name: "test"})
    end
  end
end
