defmodule LiveAdmin.Components.ContainerTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Mox

  alias LiveAdminTest.{Post, Repo, User}
  alias LiveAdminTest.Post.Version

  @endpoint LiveAdminTest.Endpoint

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LiveAdminTest.Repo)

    Mox.stub_with(LiveAdminTest.MockSession, LiveAdminTest.StubSession)

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

  describe "list resource" do
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
      view
      |> element("#index-page")
      |> render_hook("delete", %{ids: []})

      assert_redirected(view, "/user")
    end

    test "runs configured action on selected records", %{view: view} do
      view
      |> element("#index-page")
      |> render_hook("action", %{action: "user_action", ids: []})

      assert_redirected(view, "/user")
    end
  end

  describe "list resource with search param" do
    setup %{conn: conn} do
      Repo.insert!(%User{name: "Tom"})
      {:ok, view, html} = live(conn, "/user?s=fred")
      %{view: view, response: html}
    end

    test "filters results", %{view: view} do
      assert render(view) =~ "0 total"
    end

    test "clears search", %{view: view} do
      view
      |> element("button[phx-click='search']")
      |> render_click()

      assert render(view) =~ "1 total"
    end
  end

  describe "list resource with prefix param" do
    setup %{conn: conn} do
      Repo.insert!(%User{name: "Tom"}, prefix: "alt")
      {:ok, view, _} = live(conn, "/user?prefix=alt")
      %{view: view}
    end

    test "renders result from prefix", %{view: view} do
      assert render(view) =~ "1 total"
    end
  end

  describe "list resource with prefix in session" do
    setup %{conn: conn} do
      Repo.insert!(%User{name: "Tom"}, prefix: "alt")

      stub(LiveAdminTest.MockSession, :load!, fn _customer_id ->
        %LiveAdmin.Session{prefix: "alt"}
      end)

      {:ok, view, _} = live(conn, "/user")
      %{view: view}

      %{view: view}
    end

    test "renders results from prefix", %{view: view} do
      assert render(view) =~ "1 total"
    end
  end

  describe "new parent resource" do
    setup %{conn: conn} do
      {:ok, view, html} = live(conn, "/user/new")
      %{response: html, view: view}
    end

    test "includes castable form field", %{response: response} do
      assert response
             |> Floki.find("textarea[name='params[name]']")
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
      view
      |> form(".resource__form", %{params: %{name: "test"}})
      |> render_submit()

      assert [%{}] = Repo.all(User)
    end
  end

  describe "new child resource" do
    setup %{conn: conn} do
      {:ok, view, html} = live(conn, "/live_admin_test_post/new")
      %{response: html, view: view}
    end

    test "includes search select field", %{response: response} do
      assert response
             |> Floki.find("input[name='search[select]']")
             |> Enum.any?()
    end

    test "search select responds to focus", %{view: view} do
      view
      |> element("input[name='search[select]']")
      |> render_focus(%{value: "xxx"})
    end
  end

  describe "edit resource" do
    setup %{conn: conn} do
      user = Repo.insert!(%User{})
      {:ok, view, html} = live(conn, "/user/edit/#{user.id}")
      %{response: html, view: view, user: user}
    end

    test "updates record on submit", %{view: view, user: user} do
      view
      |> form(".resource__form", %{params: %{name: "test"}})
      |> render_submit()

      assert %{name: "test"} = Repo.get!(User, user.id)
    end

    test "disables immutable fields", %{response: response} do
      assert ["disabled"] ==
               response
               |> Floki.find("textarea[name='params[encrypted_password]']")
               |> Floki.attribute("disabled")
    end
  end

  describe "edit resource with embed" do
    setup %{conn: conn} do
      user = Repo.insert!(%User{settings: %{}})
      {:ok, view, html} = live(conn, "/user/edit/#{user.id}")
      %{response: html, view: view}
    end

    test "includes embed form field", %{response: response} do
      assert response
             |> Floki.find("textarea[name='params[settings][some_option]']")
             |> Enum.any?()
    end
  end

  describe "edit resource with plural embed with multiple entries" do
    setup %{conn: conn} do
      post = Repo.insert!(%Post{title: "test", previous_versions: [%Version{}, %Version{}]})
      {:ok, view, html} = live(conn, "/live_admin_test_post/edit/#{post.id}")
      %{response: html, view: view}
    end

    test "includes multiple embed fields", %{response: response} do
      assert response
             |> Floki.find("input[name='params[previous_versions]']")
             |> Enum.any?()
    end
  end

  describe "view resource" do
    setup %{conn: conn} do
      user = Repo.insert!(%User{})
      {:ok, view, html} = live(conn, "/user/#{user.id}")
      %{response: html, view: view, user: user}
    end

    test "deletes record", %{view: view} do
      view
      |> element("button", "Delete")
      |> render_click()

      assert_redirected(view, "/user")
    end
  end

  describe "view resource with associated resource" do
    setup %{conn: conn} do
      user = Repo.insert!(%User{})
      post = Repo.insert!(%Post{title: "test", user: user})
      {:ok, _, html} = live(conn, "/live_admin_test_post/#{post.id}")
      %{response: html, user: user}
    end

    test "links to user", %{response: response, user: user} do
      assert response
             |> Floki.find("a[href='/user/#{user.id}']")
             |> Enum.any?()
    end
  end
end
