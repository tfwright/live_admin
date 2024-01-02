defmodule LiveAdmin.Router do
  import Phoenix.Component, only: [assign: 2]

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

      scope unquote(path), alias: false, as: false do
        live_session :"live_admin_#{@base_path}",
          session: {unquote(__MODULE__), :build_session, [@base_path, unquote(opts)]},
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

      live("#{path}/:record_id", LiveAdmin.Components.Container, :view,
        as: :"view_#{full_path}",
        metadata: %{base_path: @base_path, resource: {path, resource_mod}}
      )

      live("#{path}/edit/:record_id", LiveAdmin.Components.Container, :edit,
        as: :"edit_#{full_path}",
        metadata: %{base_path: @base_path, resource: {path, resource_mod}}
      )
    end
  end

  def build_session(conn, base_path, opts) do
    opts_schema =
      LiveAdmin.base_configs_schema() ++
        [title: [type: :string, default: "LiveAdmin"], on_mount: [type: {:tuple, [:atom, :atom]}]]

    default_components =
      Keyword.merge(
        [
          nav: LiveAdmin.Components.Nav,
          home: LiveAdmin.Components.Home.Content,
          session: LiveAdmin.Components.Session.Content,
          new: LiveAdmin.Components.Container.Form,
          edit: LiveAdmin.Components.Container.Form,
          list: LiveAdmin.Components.Container.Index,
          view: LiveAdmin.Components.Container.View
        ],
        Application.get_env(:live_admin, :components, [])
      )

    opts =
      opts
      |> NimbleOptions.validate!(opts_schema)
      |> Keyword.put(
        :components,
        Keyword.merge(default_components, Keyword.get(opts, :components, []))
      )
      |> Keyword.put_new(:ecto_repo, Application.get_env(:live_admin, :ecto_repo))
      |> Keyword.put_new(:render_with, Application.get_env(:live_admin, :render_with))
      |> Keyword.put_new(:delete_with, Application.get_env(:live_admin, :delete_with))
      |> Keyword.put_new(:create_with, Application.get_env(:live_admin, :create_with))
      |> Keyword.put_new(:list_with, Application.get_env(:live_admin, :list_with))
      |> Keyword.put_new(:update_with, Application.get_env(:live_admin, :update_with))
      |> Keyword.put_new(:label_with, Application.get_env(:live_admin, :label_with, :id))
      |> Keyword.put_new(:title_with, Application.get_env(:live_admin, :title_with))
      |> Keyword.put_new(:validate_with, Application.get_env(:live_admin, :validate_with))
      |> Keyword.put_new(:hidden_fields, Application.get_env(:live_admin, :hidden_fields, []))
      |> Keyword.put_new(
        :immutable_fields,
        Application.get_env(:live_admin, :immutable_fields, [])
      )
      |> Keyword.put_new(:actions, Application.get_env(:live_admin, :actions, []))
      |> Keyword.put_new(:tasks, Application.get_env(:live_admin, :tasks, []))

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

    {:cont, socket}
  end
end
