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
      {:ok, view, _} = live(conn, "/")

      %{view: view}
    end

    test "links to resource", %{view: view} do
      assert has_element?(view, "a[href='/user']")
    end
  end

  describe "list resource" do
    setup %{conn: conn} do
      user = Repo.insert!(%User{})

      {:ok, view, _html} =
        live(conn, "/user?prefix=public&per=10&page=1&sort-attr=id&sort-dir=asc")

      render_async(view)

      %{view: view, user: user}
    end

    test "links to new form", %{view: view} do
      assert {_, {:live_redirect, %{to: "/user/new?prefix=public"}}} =
               view
               |> element("a[href='/user/new?prefix=public']")
               |> render_click()
    end

    test "runs configured action on selected records", %{view: view, user: user} do
      view
      |> element("tbody form")
      |> render_change(%{record_id: user.id, selected: "t"})

      view
      |> element(".drop-link", "User action")
      |> render_click()

      assert_redirect(view)
    end

    test "runs task", %{view: view} do
      view
      |> element("span", "User task")
      |> render_click()

      assert_redirected(view, "/user?prefix=public")
    end

    test "runs task with custom arity", %{view: view} do
      view
      |> element("#task-custom_arity_task-modal form")
      |> render_submit(%{name: "custom_arity_task", args: ["test"]})

      assert_redirected(view, "/user?prefix=public")
    end
  end

  describe "list resource with search param not matching any records" do
    setup %{conn: conn} do
      Repo.insert!(%User{name: "Tom"})

      {:ok, view, _} =
        live(conn, "/user?prefix=public&per=10&page=1&sort-attr=id&sort-dir=asc&s=fred")

      %{view: view}
    end

    test "shows error", %{view: view} do
      assert render_async(view) =~ "No results"
    end
  end

  describe "list resource with prefix param" do
    setup %{conn: conn} do
      Repo.insert!(%User{name: "Tom"}, prefix: "alt")

      {:ok, view, _} = live(conn, "/user?per=10&page=1&sort-attr=id&sort-dir=asc&prefix=alt")

      %{view: view}
    end

    test "renders result from prefix", %{view: view} do
      assert render_async(view) =~ "1-1/1"
    end
  end

  describe "list resource with prefix in session" do
    setup %{conn: conn} do
      Repo.insert!(%User{name: "Tom"}, prefix: "alt")

      stub(LiveAdminTest.MockSession, :load!, fn _customer_id ->
        %LiveAdmin.Session{prefix: "alt"}
      end)

      %{response: live(conn, "/user")}
    end

    test "redirects with prefix param", %{response: response} do
      assert {:error, {:live_redirect, %{kind: :push, to: "/user" <> _}}} =
               response
    end
  end

  describe "new parent resource" do
    setup %{conn: conn} do
      {:ok, view, _} = live(conn, "/user/new")

      %{view: view}
    end

    test "includes castable form field", %{view: view} do
      assert has_element?(view, "textarea[name='params[name]']")
    end

    test "handles form change", %{view: view} do
      assert view
             |> element("form")
             |> render_change()
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
      view
      |> form("form", %{params: %{name: "test"}})
      |> render_submit()

      assert [%{}] = Repo.all(User)
    end
  end

  describe "new child resource" do
    setup %{conn: conn} do
      {:ok, view, _} = live(conn, "/live_admin_test_post/new")

      %{view: view}
    end

    test "includes search select field", %{view: view} do
      assert has_element?(view, ".search-select-container")
    end
  end

  describe "edit resource" do
    setup %{conn: conn} do
      user = Repo.insert!(%User{encrypted_password: "fake"})

      {:ok, view, _} = live(conn, "/user/edit/#{user.id}")

      %{view: view, user: user}
    end

    test "updates record on submit", %{view: view, user: user} do
      view
      |> form("form", %{params: %{name: "test"}})
      |> render_submit()

      assert %{name: "test"} = Repo.get!(User, user.id)
    end

    test "disables immutable fields", %{view: view} do
      assert has_element?(view, "textarea[disabled]", "fake")
    end
  end

  describe "edit resource with embed" do
    setup %{conn: conn} do
      user = Repo.insert!(%User{settings: %{}})

      {:ok, view, _} = live(conn, "/user/edit/#{user.id}")

      %{view: view}
    end

    test "includes embed form field", %{view: view} do
      assert has_element?(view, "textarea[name='params[settings][some_option]']")
    end
  end

  describe "edit resource with plural embed with multiple entries" do
    setup %{conn: conn} do
      post = Repo.insert!(%Post{title: "test", previous_versions: [%Version{}, %Version{}]})

      {:ok, view, _} = live(conn, "/live_admin_test_post/edit/#{post.post_id}")

      %{view: view}
    end

    test "includes multiple embed fields", %{view: view} do
      assert has_element?(view, ":nth-child(2 of .embed-section)")
    end
  end

  describe "view resource" do
    setup %{conn: conn} do
      user = Repo.insert!(%User{})

      {:ok, view, _} = live(conn, "/user/#{user.id}")

      %{view: view, user: user}
    end

    test "deletes record", %{view: view} do
      view
      |> element("button", "Delete")
      |> render_click()

      assert_redirected(view, "/user?prefix=public")
    end
  end

  describe "view resource with failing action" do
    setup %{conn: conn} do
      user = Repo.insert!(%User{})

      {:ok, view, _} = live(conn, "/user/#{user.id}")

      view
      |> element(".drop-link", "Failing action")
      |> render_click()

      %{view: view}
    end

    test "shows error alert", %{view: view} do
      assert has_element?(view, ".alert-bar.error")
    end
  end

  describe "new post with custom string field" do
    setup %{conn: conn} do
      {:ok, view, _} = live(conn, "/live_admin_test_post/new")

      %{view: view}
    end

    test "includes non-disabled input field for custom string type", %{view: view} do
      assert has_element?(view, "textarea[name='params[custom_string_field]']")
    end

    test "handles form change with custom string type", %{view: view} do
      assert view
             |> element("form")
             |> render_change(%{"params" => %{"custom_string_field" => "  Trimmed Value  "}})
    end

    test "handles error from custom string type", %{view: view} do
      response =
        view
        |> element("form")
        |> render_change(%{"params" => %{"custom_string_field" => "bad string"}})

      assert response =~ "that was a bad string"
    end
  end
end
