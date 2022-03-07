defmodule LiveAdmin.Components.ContainerTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias LiveAdminTest.{Repo, User}

  @endpoint LiveAdminTest.Endpoint

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LiveAdminTest.Repo)

    %{conn: build_conn()}
  end

  describe "resource page" do
    setup %{conn: conn} do
      Repo.insert!(%User{})
      {:ok, view, _html} = live(conn, "/user")
      %{view: view}
    end

    test "links to new form", %{view: view} do
      assert {_, {:live_redirect, %{to: "/user/new"}}} =
               view
               |> element("a[href='/user/new'")
               |> render_click()
    end

    test "deletes record", %{view: view} do
      assert {_, {:live_redirect, %{to: "/user?page=1"}}} =
               view
               |> element("a[phx-click='delete']")
               |> render_click()
    end

    test "runs configured actions", %{view: view} do
      assert {_, {:live_redirect, %{to: "/user?page=1"}}} =
               view
               |> element("a[phx-value-action='run_action']")
               |> render_click()
    end
  end

  describe "new resource page" do
    setup %{conn: conn} do
      {:ok, view, html} = live(conn, "/user/new")
      %{response: html, view: view}
    end

    test "includes castable form field", %{response: response} do
      assert response
             |> Floki.find("textarea[name='params[name]']")
             |> Enum.any?()
    end

    test "includes embed form field", %{response: response} do
      assert response
             |> Floki.find("textarea[name='params[settings][some_option]']")
             |> Enum.any?()
    end

    test "handles form change", %{view: view} do
      assert view
             |> element(".resource__form")
             |> render_change()
    end

    test "persists all form changes", %{view: view} do
      response =
        view
        |> element(".resource__form")
        |> render_change(%{
          "params" => %{"name" => "test name", "settings" => %{"some_option" => "test option"}}
        })

      assert response =~ "test option"
      assert response =~ "test name"
    end

    test "creates user on form submit", %{view: view} do
      {_, {:live_redirect, %{to: "/user"}}} =
        view
        |> element(".resource__form")
        |> render_submit(%{name: "test", settings: %{some_option: "test"}})

      assert [%{}] = Repo.all(User)
    end
  end

  describe "edit resource page" do
    setup %{conn: conn} do
      user = Repo.insert!(%User{})
      {:ok, view, html} = live(conn, "/user/edit/#{user.id}")
      %{response: html, view: view}
    end

    test "handles form submit", %{view: view} do
      {_, {:live_redirect, %{to: "/user"}}} =
        view
        |> element(".resource__form")
        |> render_submit(%{name: "test"})
    end

    test "disables immutable fields", %{response: response} do
      assert ["disabled"] ==
               response
               |> Floki.find("textarea[name='params[password]']")
               |> Floki.attribute("disabled")
    end
  end
end
