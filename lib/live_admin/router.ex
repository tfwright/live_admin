defmodule LiveAdmin.Router do
  import Phoenix.Component, only: [assign: 2]

  alias LiveAdmin.Resource

  @doc """
  Defines a route that can be used to access the Admin UI for all configured resources.

  ## Arguments

  * `:path` - Defines a scope to be added to the router under which the resources will be grouped in a single live session
  * `:opts` - Opts for the Admin UI added at configured path
    * `:resources` - A list of Ecto schema modules to be exposed in the UI
    * `:title` - Title for the UI home view (Default: 'LiveAdmin')
    * `:components` - A list of UI level component overrides
      * `:home` - Override for the view loaded at the base path, before the user navigates to a specific resource
  """
  defmacro live_admin(path, opts) do
    resources = Keyword.get(opts, :resources, [])
    title = Keyword.get(opts, :title, "LiveAdmin")
    components = Keyword.get(opts, :components, [])

    quote do
      scope unquote(path), alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        live_session :live_admin,
          session:
            {unquote(__MODULE__), :build_session,
             [unquote(resources), unquote(title), unquote(components)]},
          root_layout: {LiveAdmin.View, :layout},
          on_mount: {unquote(__MODULE__), :assign_options} do
          live("/", LiveAdmin.Components.Home, :home, as: :home)
          live("/:resource_id", LiveAdmin.Components.Container, :list, as: :resource)
          live("/:resource_id/new", LiveAdmin.Components.Container, :new, as: :resource)

          live("/:resource_id/edit/:record_id", LiveAdmin.Components.Container, :edit,
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
        resource_params =
          case config do
            {mod, opts} -> [schema: mod, config: Map.new(opts)]
            mod -> [schema: mod, config: %{}]
          end

        resource_path =
          resource_params
          |> Keyword.fetch!(:schema)
          |> Module.split()

        {
          struct!(Resource, resource_params),
          (base_path || Enum.drop(resource_path, -1))
          |> Enum.zip(resource_path)
          |> Enum.reduce_while([], fn
            {a, a}, new_path -> {:cont, Enum.concat(new_path, [a])}
            _, new_path -> {:halt, new_path}
          end)
        }
      end)

    resources_by_key =
      Map.new(resources, fn r -> {derive_resource_key(r.schema, base_path), r} end)

    {:cont,
     assign(socket,
       title: title,
       resources: resources_by_key,
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
