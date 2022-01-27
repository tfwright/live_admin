defmodule Phoenix.LiveAdmin.Router do
  import Phoenix.LiveView, only: [assign: 2]

  defmacro live_admin(path, opts) do
    resources = Keyword.get(opts, :resources, [])
    title = Keyword.get(opts, :title, "Phoenix LiveAdmin")
    components = Keyword.get(opts, :components, [])

    quote do
      scope unquote(path), alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        live_session :live_admin,
          session:
            {unquote(__MODULE__), :build_session,
             [unquote(resources), unquote(title), unquote(components)]},
          root_layout: {Phoenix.LiveAdmin.View, "layout.html"},
          on_mount: {unquote(__MODULE__), :assign_options} do
          live("/", Phoenix.LiveAdmin.Components.Home, :home, as: :home)
          live("/:resource_id", Phoenix.LiveAdmin.Components.Resource, :list, as: :resource)
          live("/:resource_id/new", Phoenix.LiveAdmin.Components.Resource, :new, as: :resource)

          live("/:resource_id/edit/:record_id", Phoenix.LiveAdmin.Components.Resource, :edit,
            as: :resource
          )
        end
      end
    end
  end

  def on_mount(
        :assign_options,
        _params,
        %{"resources" => resources, "title" => title, "components" => components},
        socket
      ) do
    resources =
      resources
      |> Enum.map(fn
        {mod, opts} -> {derive_resource_key(mod), {mod, Map.new(opts)}}
        mod -> {derive_resource_key(mod), {mod, %{}}}
      end)
      |> Enum.into(%{})

    {:cont,
     assign(socket, title: title, resources: resources, socket: socket, components: components)}
  end

  defp derive_resource_key(mod) do
    mod
    |> to_string()
    |> String.split(".")
    |> Enum.slice(-2, 2)
    |> Enum.map_join("_", &Macro.underscore/1)
  end

  def build_session(_conn, resources, title, components) do
    %{
      "resources" => resources,
      "id" => generate_uuid(),
      "title" => title,
      "components" => components
    }
  end

  defp generate_uuid() do
    make_ref()
    |> :erlang.ref_to_list()
    |> List.to_string()
  end
end
