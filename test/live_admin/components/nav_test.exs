defmodule LiveAdmin.Components.NavTest do
  use ExUnit.Case, async: true
  alias LiveAdmin.Components.Nav

  defmodule DummyLive do
    use Phoenix.LiveView
  end

  defmodule DummyController do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end

  defmodule FakeRouter do
    def __routes__ do
      [
        %Phoenix.Router.Route{
          verb: "GET",
          path: "/admin/metrics",
          helper: :admin_metrics,
          plug: DummyController,
          plug_opts: :index,
          metadata: %{
            phoenix_live_view: {
              DummyLive,
              :index,
              [],
              %{extra: %{custom: true}}
            }
          }
        },
        %Phoenix.Router.Route{
          verb: "GET",
          path: "/admin/session",
          helper: :admin_session,
          plug: DummyController,
          plug_opts: :index,
          metadata: %{
            resource: nil,
            phoenix_live_view: {
              DummyLive,
              :index,
              [],
              %{extra: %{session: true}}
            }
          }
        }
      ]
    end
  end

  test "only extra non-session routes are assigned as extra_pages" do
    assigns = %{
      id: :nav_test,
      base_path: "/admin",
      config: [],
      router: FakeRouter,
      resources: [],
      resource: nil
    }

    socket =
      %Phoenix.LiveView.Socket{
        endpoint: DummyEndpoint,
        router: FakeRouter,
        view: DummyLive,
        assigns: %{__changed__: %{}}
      }

    {:ok, socket} = Nav.update(assigns, socket)

    extra_paths = Enum.map(socket.assigns.extra_pages, & &1.path)

    assert "/admin/metrics" in extra_paths
    refute "/admin/session" in extra_paths
  end
end
