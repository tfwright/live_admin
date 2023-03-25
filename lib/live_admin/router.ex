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
  """
  defmacro live_admin(path, opts) do
    resources = Keyword.get(opts, :resources, [])
    title = Keyword.get(opts, :title, "LiveAdmin")

    quote do
      scope unquote(path), alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        live_session :live_admin,
          session: {unquote(__MODULE__), :build_session, [unquote(resources), unquote(title)]},
          root_layout: {LiveAdmin.View, :layout},
          layout: {LiveAdmin.View, :app},
          on_mount: {unquote(__MODULE__), :assign_options} do
          live("/", LiveAdmin.Components.Home, :home, as: :__live_admin_home)
          live("/:resource_id", LiveAdmin.Components.Container, :list, as: :__live_admin_index__)
          live("/:resource_id/new", LiveAdmin.Components.Container, :new, as: :__live_admin_new__)

          live("/:resource_id/edit/:record_id", LiveAdmin.Components.Container, :edit,
            as: :__live_admin_edit__
          )
        end
      end

      live_admin_path =
        __MODULE__
        |> Module.get_attribute(:phoenix_top_scopes)
        |> Map.fetch!(:path)
        |> Path.join(unquote(path))

      @live_admin_path live_admin_path

      def __live_admin_path__, do: "/#{@live_admin_path}"
    end
  end

  def on_mount(
        :assign_options,
        _params,
        %{"resources" => resources, "title" => title},
        socket
      ) do
    resources_by_key =
      resources
      |> Enum.map(fn config ->
        resource_params =
          case config do
            {mod, opts} -> [schema: mod, config: Map.new(opts)]
            mod when is_atom(mod) -> [schema: mod, config: %{}]
          end

        resource = struct!(Resource, resource_params)

        {generate_resource_key(resource), resource}
      end)
      |> Enum.into(%{})

    {:cont, assign(socket, title: title, resources: resources_by_key)}
  end

  def generate_resource_key(resource) do
    case LiveAdmin.get_config(resource, :slug_with) do
      nil -> resource.schema |> Module.split() |> Enum.map_join("_", &Macro.underscore/1)
      {m, f, a} -> apply(m, f, a)
      slug when is_binary(slug) -> slug
    end
  end

  def build_session(conn, resources, title) do
    %{
      "resources" => resources,
      "session_id" => LiveAdmin.session_store().init!(conn),
      "title" => title
    }
  end
end
