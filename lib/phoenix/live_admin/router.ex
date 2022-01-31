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
    {resources, base_path} =
      resources
      |> Enum.map_reduce(nil, fn config, base_path ->
        resource =
          {mod, _} =
          config
          |> case do
            {mod, opts} -> {mod, Map.new(opts)}
            mod -> {mod, %{}}
          end

        resource_path = Module.split(mod)

        {
          resource,
          (base_path || Enum.drop(resource_path, -1))
          |> Enum.zip(resource_path)
          |> Enum.reduce_while([], fn
            {a, a}, new_path -> {:cont, Enum.concat(new_path, [a])}
            _, new_path -> {:halt, new_path}
          end)
        }
      end)

    resources =
      Map.new(resources, fn resource ->
        {derive_resource_key(elem(resource, 0), base_path), resource}
      end)

    {:cont,
     assign(socket,
       title: title,
       resources: resources,
       socket: socket,
       components: components,
       base_path: base_path
     )}
  end

  defp derive_resource_key(mod, base_path) do
    mod
    |> Module.split()
    |> Enum.drop(Enum.count(base_path))
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
