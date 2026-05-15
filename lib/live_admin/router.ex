defmodule LiveAdmin.Router do
  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [attach_hook: 4]

  @doc """
  Defines a group of LiveAdmin resources that share a common path prefix, and optionally, configuration.

  ## Arguments

  * `path` - Defines a scope to be added to the router under which the resources will be grouped in a single live session
  * `opts` - Configuration for this LiveAdmin scope. In addition to global options:
    - `title` (binary) - Title to display in nav bar
    - `on_mount` (tuple) - Module function when routes are mounted that will receive and should return session
  """
  defmacro live_admin(path, opts \\ [], do: context) do
    import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

    quote do
      current_path =
        __MODULE__
        |> Module.get_attribute(:phoenix_top_scopes)
        |> Map.fetch!(:path)

      @base_path Path.join(["/", current_path, unquote(path)])
      @__live_admin_scope_opts__ unquote(opts)
      @__live_admin_app_config__ [
        components: Application.compile_env(:live_admin, :components, []),
        query_with: Application.compile_env(:live_admin, :query_with),
        render_with: Application.compile_env(:live_admin, :render_with),
        delete_with: Application.compile_env(:live_admin, :delete_with),
        create_with: Application.compile_env(:live_admin, :create_with),
        update_with: Application.compile_env(:live_admin, :update_with),
        validate_with: Application.compile_env(:live_admin, :validate_with),
        label_with: Application.compile_env(:live_admin, :label_with),
        title_with: Application.compile_env(:live_admin, :title_with),
        hidden_fields: Application.compile_env(:live_admin, :hidden_fields, []),
        immutable_fields: Application.compile_env(:live_admin, :immutable_fields, []),
        actions: Application.compile_env(:live_admin, :actions, []),
        tasks: Application.compile_env(:live_admin, :tasks, [])
      ]

      scope unquote(path), alias: false, as: false do
        live_session :"live_admin_#{@base_path}",
          session:
            {unquote(__MODULE__), :build_session,
             [@base_path, unquote(opts), @__live_admin_app_config__]},
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
      LiveAdmin.Router.__validate_config__!(
        resource_mod,
        @__live_admin_scope_opts__,
        @__live_admin_app_config__
      )

      full_path = Path.join(@base_path, path)

      live(path, LiveAdmin.Components.Container, :index,
        as: :"index_#{full_path}",
        metadata: %{base_path: @base_path, resource: {path, resource_mod}}
      )

      live("#{path}/new", LiveAdmin.Components.Container, :create,
        as: :"create_#{full_path}",
        metadata: %{base_path: @base_path, resource: {path, resource_mod}}
      )

      live("#{path}/:record_id", LiveAdmin.Components.Container, :show,
        as: :"show_#{full_path}",
        metadata: %{base_path: @base_path, resource: {path, resource_mod}}
      )

      live("#{path}/edit/:record_id", LiveAdmin.Components.Container, :edit,
        as: :"edit_#{full_path}",
        metadata: %{base_path: @base_path, resource: {path, resource_mod}}
      )
    end
  end

  @disabled_with_custom_component [
    {:create_with, :create},
    {:update_with, :edit}
  ]

  @doc false
  def __validate_config__!(resource_mod, scope_opts, app_opts) do
    Code.ensure_compiled!(resource_mod)
    resource_opts = resource_mod.__live_admin_config__()
    levels = [resource_opts, scope_opts, app_opts]

    Enum.each(levels, fn level ->
      Enum.each(@disabled_with_custom_component, fn {with_key, component_key} ->
        disabled? = Keyword.get(level, with_key) == false
        component_set? = Keyword.has_key?(Keyword.get(level, :components, []), component_key)

        if disabled? and component_set? do
          raise ArgumentError,
                "invalid config for resource #{inspect(resource_mod)}: " <>
                  "#{with_key}: false cannot be combined with a custom :#{component_key} component at the same level"
        end
      end)
    end)
  end

  def build_session(conn, base_path, opts, app_config) do
    opts_schema =
      LiveAdmin.base_configs_schema() ++
        [title: [type: :string, default: "LiveAdmin"], on_mount: [type: {:tuple, [:atom, :atom]}]]

    default_components =
      Keyword.merge(
        [
          nav: LiveAdmin.Components.Nav,
          home: LiveAdmin.Components.Home.Content,
          session: LiveAdmin.Components.Session.Content,
          create: LiveAdmin.Components.Container.Form,
          edit: LiveAdmin.Components.Container.Form,
          index: LiveAdmin.Components.Container.Index,
          show: LiveAdmin.Components.Container.Show
        ],
        Keyword.get(app_config, :components, [])
      )

    opts =
      opts
      |> NimbleOptions.validate!(opts_schema)
      |> Keyword.put(
        :components,
        Keyword.merge(default_components, Keyword.get(opts, :components, []))
      )
      |> Keyword.put_new(:ecto_repo, Application.get_env(:live_admin, :ecto_repo))
      |> Keyword.put_new(:render_with, Keyword.get(app_config, :render_with))
      |> Keyword.put_new(:delete_with, Keyword.get(app_config, :delete_with))
      |> Keyword.put_new(:create_with, Keyword.get(app_config, :create_with))
      |> Keyword.put_new(:query_with, Keyword.get(app_config, :query_with))
      |> Keyword.put_new(:update_with, Keyword.get(app_config, :update_with))
      |> Keyword.put_new(:label_with, Keyword.get(app_config, :label_with))
      |> Keyword.put_new(:title_with, Keyword.get(app_config, :title_with))
      |> Keyword.put_new(:validate_with, Keyword.get(app_config, :validate_with))
      |> Keyword.put_new(:hidden_fields, Keyword.get(app_config, :hidden_fields, []))
      |> Keyword.put_new(:immutable_fields, Keyword.get(app_config, :immutable_fields, []))
      |> Keyword.put_new(:actions, Keyword.get(app_config, :actions, []))
      |> Keyword.put_new(:tasks, Keyword.get(app_config, :tasks, []))

    %{
      "session_id" => LiveAdmin.session_store().init!(conn),
      "base_path" => base_path,
      "opts" => opts
    }
  end

  def on_mount(
        :assign_options,
        _params,
        %{
          "base_path" => base_path,
          "session_id" => session_id,
          "opts" => opts
        },
        socket
      ) do
    session = LiveAdmin.session_store().load!(session_id)

    Gettext.put_locale(LiveAdmin.gettext_backend(), session.locale)

    socket =
      assign(socket,
        session: session,
        base_path: base_path,
        resources: LiveAdmin.resources(socket.router, base_path),
        config: opts
      )

    socket =
      case Keyword.get(opts, :on_mount) do
        {m, f} -> apply(m, f, [socket])
        _ -> socket
      end

    socket =
      attach_hook(socket, :nav_uri, :handle_params, fn _params, uri, socket ->
        LiveAdmin.PubSub.broadcast(session_id, {:nav, %{uri: uri}})
        {:cont, socket}
      end)

    {:cont, socket}
  end

  def on_mount(_, _params, _, socket), do: {:cont, socket}
end
