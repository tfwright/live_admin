defmodule Phoenix.LiveAdmin.Router do
  import Phoenix.LiveView, only: [assign: 2]

  defmacro live_admin(path, opts) do
    resources = Keyword.get(opts, :resources, [])

    quote do
      scope unquote(path), alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        live_session :live_admin,
          session: %{"resources" => unquote(resources)},
          root_layout: {Phoenix.LiveAdmin.LayoutView, "live.html"},
          on_mount: {unquote(__MODULE__), :assign_resources} do
          live("/", Phoenix.LiveAdmin.Components.Home, :home, as: :home)
          live("/:resource", Phoenix.LiveAdmin.Components.Resource, :list, as: :resource)
          live("/:resource/new", Phoenix.LiveAdmin.Components.Resource, :new, as: :resource)
        end
      end
    end
  end

  def on_mount(:assign_resources, _params, %{"resources" => resources}, socket) do
    {:cont, assign(socket, resources: resources, socket: socket)}
  end
end
