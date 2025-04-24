defmodule LiveAdmin.Components.NavTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest
  alias LiveAdmin.Components.Nav

  defmodule DummyLive do
    use Phoenix.LiveView
  end

  defmodule DummyController do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end

  defmodule FakeRouter do
    @base "/admin"

    def __routes__ do
      [
        # 1) Home (base path)
        # - should be excluded from extra_pages
        # - but later hardcoded in the nav component
        %Phoenix.Router.Route{
          verb: "GET",
          path: @base,
          helper: nil,
          plug: Phoenix.LiveView.Plug,
          plug_opts: :"home_/admin",
          metadata: %{
            phoenix_live_view: {DummyLive, :home, [], %{extra: %{layout: true}}}
          }
        },

        # 2) Custom extra pages
        # - should be included in extra_pages
        %Phoenix.Router.Route{
          verb: "GET",
          path: "#{@base}/metrics",
          helper: :admin_metrics,
          plug: DummyController,
          plug_opts: :index,
          metadata: %{
            phoenix_live_view: {DummyLive, :index, [], %{extra: %{custom: true}}}
          }
        },
        %Phoenix.Router.Route{
          verb: "GET",
          path: "/admin/alpha",
          helper: :admin_alpha,
          plug: DummyController,
          plug_opts: :index,
          metadata: %{
            phoenix_live_view: {DummyLive, :index, [], %{extra: %{foo: true}}}
          }
        },
        %Phoenix.Router.Route{
          verb: "GET",
          path: "/admin/zeta",
          helper: :admin_zeta,
          plug: DummyController,
          plug_opts: :index,
          metadata: %{
            phoenix_live_view: {DummyLive, :index, [], %{extra: %{bar: true}}}
          }
        },

        # 3) Session page
        # - should be excluded from extra_pages
        # - but later hardcoded in the nav component
        %Phoenix.Router.Route{
          verb: "GET",
          path: "#{@base}/session",
          helper: :admin_session,
          plug: DummyController,
          plug_opts: :index,
          metadata: %{
            resource: nil,
            phoenix_live_view: {DummyLive, :index, [], %{extra: %{session: true}}}
          }
        },

        # 4) Resource route
        # - should be excluded
        # - edge case bonus: somehow shares the base path
        %Phoenix.Router.Route{
          verb: "GET",
          path: "#{@base}/entries",
          helper: nil,
          plug: Phoenix.LiveView.Plug,
          plug_opts: :"list_/admin/entries",
          metadata: %{
            resource: {"/entries", MyApp.Entries.Entry},
            phoenix_live_view: {DummyLive, :list, [], %{extra: %{layout: true}}}
          }
        },

        # 5) Non-admin path
        # - should be excluded
        %Phoenix.Router.Route{
          verb: "GET",
          path: "/log",
          helper: nil,
          plug: DummyController,
          plug_opts: nil,
          metadata: %{log: :debug}
        },

        # 6) Contains only session key
        # - should be excluded
        # - `not_session_path?/2` removes `/admin/session` by path, but…
        #   If someone mounted a custom LiveView at some other URL
        #   and only passed `extra: %{session: …}` (say via a plug),
        #   the only way to tell the component to exclude it is by
        #   inspecting the metadata keys.
        %Phoenix.Router.Route{
          verb: "GET",
          path: "#{@base}/user/preferences",
          helper: :admin_user_preferences,
          plug: Phoenix.LiveView.Plug,
          plug_opts: :"Elixir.MyApp.UserPreferencesLive",
          metadata: %{
            phoenix_live_view: {DummyLive, :index, [], %{extra: %{session: %{foo: "bar"}}}}
          }
        }
      ]
    end
  end

  setup do
    assigns = %{
      id: :nav_test,
      base_path: "/admin",
      config: [title: "Test"],
      router: FakeRouter,
      resources: [],
      resource: nil
    }

    socket = %Phoenix.LiveView.Socket{
      endpoint: MyApp.Endpoint,
      router: FakeRouter,
      view: DummyLive,
      assigns: %{__changed__: %{}}
    }

    {:ok, assigns: assigns, socket: socket}
  end

  test "extra_pages contains only admin scoped routes, filters out base and session", %{
    assigns: assigns,
    socket: socket
  } do
    {:ok, socket} = Nav.update(assigns, socket)

    extra_paths = Enum.map(socket.assigns.extra_pages, & &1.path)
    assert extra_paths == ["/admin/alpha", "/admin/metrics", "/admin/zeta"]
  end

  test "renders the navigation component with correct routes", %{assigns: assigns} do
    html = render_component(Nav, assigns, router: FakeRouter)

    # Should include links to custom admin_resource routes
    assert html =~ ~s|href="/admin/alpha"|
    assert html =~ ~s|href="/admin/metrics"|
    assert html =~ ~s|href="/admin/zeta"|

    # Excluded from assigns.extra_pages but hardcoded in the nav component
    assert html =~ ~s|href="/admin"|
    assert html =~ ~s|href="/admin/session"|

    # Should not include links to excluded routes
    refute html =~ ~s|href="/admin/entries"|
    refute html =~ ~s|href="/log"|
    refute html =~ ~s|href="/admin/user/preferences"|
  end
end
