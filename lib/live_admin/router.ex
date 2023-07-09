defmodule LiveAdmin.Router do
  import Phoenix.Component, only: [assign: 2]

  @doc """
  Defines a group of LiveAdmin resources that share a common prefix, and optionally, configuration.

  ## Arguments

  * `path` - Defines a scope to be added to the router under which the resources will be grouped in a single live session
  * `opts` - Opts for the Admin UI added at configured path
    * `:title` - Title for the UI home view (Default: 'LiveAdmin')
    * `:components` - Component overrides that will be used for every resource in the group
      unless a resource is configurated to use its own overrides.
  """
  defmacro live_admin(path, opts \\ [], do: context) do
    import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

    title = Keyword.get(opts, :title, "LiveAdmin")
    components = Keyword.get(opts, :components, Application.get_env(:live_admin, :components, []))
    repo = Keyword.get(opts, :ecto_repo, Application.get_env(:live_admin, :ecto_repo))

    quote do
      current_path =
        __MODULE__
        |> Module.get_attribute(:phoenix_top_scopes)
        |> Map.fetch!(:path)

      @base_path Path.join(["/", current_path, unquote(path)])

      scope unquote(path), alias: false, as: false do
        live_session :"live_admin_#{@base_path}",
          session:
            {unquote(__MODULE__), :build_session,
             [@base_path, unquote(title), unquote(components), unquote(repo)]},
          root_layout: {LiveAdmin.View, :layout},
          layout: {LiveAdmin.View, :app},
          on_mount: {unquote(__MODULE__), :assign_options} do
          live("/", LiveAdmin.Components.Home, :"home_#{@base_path}", as: :"home_#{@base_path}")

          live("/session", LiveAdmin.Components.Session, :"session_#{@base_path}",
            as: :"session_#{@base_path}"
          )

          unquote(context)
        end
      end
    end
  end

  @doc """
  Defines a resource to be included in a LiveAdmin UI.

  For each configured resource at path `/foo`, the following routes will be added:

  * `/foo` - List view
  * `/foo/new` - New record form
  * `/foo/:id/edit` - Update record form
  """
  defmacro admin_resource(path, resource_mod) do
    import Phoenix.LiveView.Router, only: [live: 4]

    quote bind_quoted: [path: path, resource_mod: resource_mod] do
      full_path = Path.join(@base_path, path)

      live(path, LiveAdmin.Components.Container, :list,
        as: :"list_#{full_path}",
        metadata: %{base_path: @base_path, resource: {path, resource_mod}}
      )

      live("#{path}/new", LiveAdmin.Components.Container, :new,
        as: :"new_#{full_path}",
        metadata: %{base_path: @base_path, resource: {path, resource_mod}}
      )

      live("#{path}/edit/:record_id", LiveAdmin.Components.Container, :edit,
        as: :"edit_#{full_path}",
        metadata: %{base_path: @base_path, resource: {path, resource_mod}}
      )
    end
  end

  def build_session(conn, base_path, title, components, repo) do
    %{
      "session_id" => LiveAdmin.session_store().init!(conn),
      "base_path" => base_path,
      "title" => title,
      "components" => components |> add_default_components() |> Enum.into(%{}),
      "repo" => repo
    }
  end

  def on_mount(
        :assign_options,
        _params,
        %{
          "title" => title,
          "base_path" => base_path,
          "components" => components,
          "session_id" => session_id,
          "repo" => repo
        },
        socket
      ) do
    session = LiveAdmin.session_store().load!(session_id)

    Gettext.put_locale(LiveAdmin.gettext_backend(), session.locale)

    {:cont,
     assign(socket,
       session: session,
       base_path: base_path,
       title: title,
       nav_mod: Map.fetch!(components, :nav),
       resources: socket.router |> Phoenix.Router.routes() |> collect_resources(base_path),
       default_repo: repo
     )}
  end

  defp add_default_components(components) do
    components
    |> Keyword.put_new(:nav, LiveAdmin.Components.Nav)
    |> Keyword.put_new(:home, LiveAdmin.Components.Home.Content)
    |> Keyword.put_new(:session, LiveAdmin.Components.Session.Content)
    |> Keyword.put_new(:new, LiveAdmin.Components.Container.Form)
    |> Keyword.put_new(:edit, LiveAdmin.Components.Container.Form)
    |> Keyword.put_new(:list, LiveAdmin.Components.Container.Index)
  end

  defp collect_resources(routes, base_path) do
    Enum.flat_map(routes, fn
      %{metadata: %{base_path: ^base_path, resource: resource}} -> [resource]
      _ -> []
    end)
  end
end
