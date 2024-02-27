defmodule LiveAdmin.Components.Container do
  use Phoenix.LiveView
  use PhoenixHTMLHelpers

  import LiveAdmin,
    only: [
      resource_title: 2,
      route_with_params: 1,
      route_with_params: 2,
      trans: 1
    ]

  import LiveAdmin.Components
  import LiveAdmin.View, only: [get_function_keys: 3]

  alias LiveAdmin.Resource
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket, loading: !connected?(socket))

    if connected?(socket), do: Process.send_after(self(), :clear_flash, 2000)

    {:ok, socket}
  end

  @impl true
  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  @impl true
  def handle_params(
        params = %{"record_id" => id},
        uri,
        socket = %{assigns: %{live_action: action, loading: false}}
      )
      when action in [:edit, :view] do
    socket =
      socket
      |> assign_resource_info(uri)
      |> assign_mod()
      |> assign_repo()
      |> assign_prefix(params)

    record =
      Resource.find(
        id,
        socket.assigns.resource,
        socket.assigns[:prefix],
        socket.assigns.repo
      )

    socket = assign(socket, record: record)

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, uri, socket = %{assigns: %{live_action: :list, loading: false}}) do
    socket =
      socket
      |> assign(search: params["s"])
      |> assign_resource_info(uri)
      |> assign_pagination_params(params)
      |> assign_mod()
      |> assign_repo()
      |> assign_prefix(params)

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, uri, socket = %{assigns: %{live_action: :new}}),
    do:
      {:noreply,
       socket
       |> assign_resource_info(uri)
       |> assign_mod()
       |> assign_repo()
       |> assign_prefix(params)}

  def handle_params(_, _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_locale", %{"locale" => locale}, socket) do
    new_session = Map.put(socket.assigns.session, :locale, locale)

    LiveAdmin.session_store().persist!(new_session)

    {:noreply, assign(socket, :session, new_session)}
  end

  def render(assigns = %{loading: true}), do: ~H""

  @impl true
  def render(assigns) do
    ~H"""
    <div class="resource__banner">
      <h1 class="resource__title">
        <%= resource_title(@resource, @config) %>
      </h1>

      <div class="resource__actions">
        <div>
          <.link
            navigate={route_with_params(assigns, params: [prefix: @prefix])}
            class="resource__action--btn"
          >
            <%= trans("List") %>
          </.link>
          <%= if LiveAdmin.fetch_config(@resource, :create_with, @config) != false do %>
            <.link
              navigate={route_with_params(assigns, segments: ["new"], params: [prefix: @prefix])}
              class="resource__action--btn"
            >
              <%= trans("New") %>
            </.link>
          <% else %>
            <button class="resource__action--disabled" disabled="disabled">
              <%= trans("New") %>
            </button>
          <% end %>
          <.dropdown
            :let={task}
            label={trans("Run task")}
            items={get_function_keys(@resource, @config, :tasks)}
            disabled={Enum.empty?(get_function_keys(@resource, @config, :tasks))}
          >
            <.task_control task={task} session={@session} resource={@resource} />
          </.dropdown>
          <%= if Enum.any?(@prefix_options) do %>
            <.dropdown
              :let={prefix}
              id="prefix-select"
              label={@prefix || trans("Set prefix")}
              items={[""] ++ Enum.filter(@prefix_options, &(to_string(&1) != @prefix))}
            >
              <.link navigate={route_with_params(assigns, params: [prefix: prefix])}>
                <%= if prefix == "", do: trans("clear"), else: prefix %>
              </.link>
            </.dropdown>
          <% end %>
          <%= if LiveAdmin.use_i18n? do %>
            <.dropdown
              :let={locale}
              id="locale-select"
              label={@session.locale || "Set locale"}
              items={
                Enum.filter(
                  LiveAdmin.gettext_backend().locales(),
                  &(to_string(&1) != @session.locale)
                )
              }
            >
              <button
                class="resource__action--link"
                phx-click={JS.push("set_locale", value: %{locale: locale}, page_loading: true)}
              >
                <%= locale %>
              </button>
            </.dropdown>
          <% end %>
        </div>
      </div>
    </div>

    <%= render("#{@live_action}.html", assigns) %>
    """
  end

  def render("list.html", assigns) do
    ~H"""
    <.live_component
      module={@mod}
      id="list"
      key={@key}
      resource={@resource}
      page={@page}
      sort_attr={@sort_attr}
      sort_dir={@sort_dir}
      search={@search}
      prefix={@prefix}
      session={@session}
      base_path={@base_path}
      resources={@resources}
      repo={@repo}
      config={@config}
    />
    """
  end

  def render("new.html", assigns) do
    ~H"""
    <.live_component
      module={@mod}
      id="form"
      action="create"
      session={@session}
      key={@key}
      resources={@resources}
      resource={@resource}
      prefix={@prefix}
      base_path={@base_path}
      repo={@repo}
      config={@config}
    />
    """
  end

  def render("edit.html", assigns) do
    ~H"""
    <.live_component
      module={@mod}
      id="form"
      action="update"
      session={@session}
      key={@key}
      record={@record}
      resources={@resources}
      resource={@resource}
      prefix={@prefix}
      repo={@repo}
      base_path={@base_path}
      config={@config}
    />
    """
  end

  def render("view.html", assigns) do
    ~H"""
    <.live_component
      module={@mod}
      id="view"
      record={@record}
      resource={@resource}
      resources={@resources}
      session={@session}
      key={@key}
      base_path={@base_path}
      prefix={@prefix}
      repo={@repo}
      config={@config}
    />
    """
  end

  defp assign_prefix(socket, %{"prefix" => ""}) do
    socket
    |> assign_and_presist_prefix(nil)
    |> push_redirect(to: route_with_params(socket.assigns))
  end

  defp assign_prefix(socket, %{"prefix" => prefix}) do
    socket.assigns.prefix_options
    |> Enum.find(fn option -> to_string(option) == prefix end)
    |> case do
      nil ->
        push_redirect(socket, to: route_with_params(socket.assigns, params: [prefix: ""]))

      prefix ->
        assign_and_presist_prefix(socket, prefix)
    end
  end

  defp assign_prefix(socket = %{assigns: %{session: session}}, _) do
    case session.prefix do
      nil ->
        assign_and_presist_prefix(socket, nil)

      prefix ->
        push_patch(socket, to: route_with_params(socket.assigns, params: [prefix: prefix]))
    end
  end

  defp assign_and_presist_prefix(socket, prefix) do
    new_session = Map.put(socket.assigns.session, :prefix, prefix)

    LiveAdmin.session_store().persist!(new_session)

    assign(socket, prefix: prefix, session: new_session)
  end

  defp assign_resource_info(socket, uri) do
    %URI{host: host, path: path} = URI.parse(uri)

    %{resource: {key, mod}} = Phoenix.Router.route_info(socket.router, "GET", path, host)

    assign(socket, key: key, resource: mod)
  end

  defp assign_mod(socket = %{assigns: %{resource: resource, live_action: action, config: config}}) do
    mod =
      resource
      |> LiveAdmin.fetch_config(:components, config)
      |> Keyword.fetch!(action)

    assign(socket, :mod, mod)
  end

  defp assign_repo(socket = %{assigns: %{resource: resource, config: config}}) do
    repo = LiveAdmin.fetch_config(resource, :ecto_repo, config)

    prefix_options =
      if function_exported?(repo, :prefixes, 0) do
        repo.prefixes()
      else
        []
      end

    assign(socket, repo: repo, prefix_options: prefix_options)
  end

  defp assign_pagination_params(socket, params) do
    params =
      Map.new(params, fn
        {"sort-attr", val} -> {"sort_attr", val}
        {"sort-dir", val} -> {"sort_dir", val}
        pair -> pair
      end)

    types =
      %{
        page: :integer,
        sort_attr:
          Ecto.ParameterizedType.init(Ecto.Enum,
            values:
              socket.assigns.resource
              |> LiveAdmin.Resource.fields(socket.assigns.config)
              |> Enum.map(fn {field, _, _} -> field end)
          ),
        sort_dir: Ecto.ParameterizedType.init(Ecto.Enum, values: [:asc, :desc])
      }

    defaults = %{
      page: 1,
      sort_attr: LiveAdmin.primary_key!(socket.assigns.resource),
      sort_dir: :asc
    }

    params =
      {defaults, types}
      |> Ecto.Changeset.cast(params, Map.keys(types))
      |> Ecto.Changeset.apply_action!(:update)

    assign(socket, params)
  end

  defp task_control(assigns) do
    {name, _, _, arity, docs} =
      LiveAdmin.fetch_function(assigns.resource, assigns.session, :tasks, assigns.task)

    extra_arg_count = arity - 1

    assigns =
      assign(assigns,
        extra_arg_count: extra_arg_count,
        function_docs: docs,
        modalize: extra_arg_count > 0 or Enum.any?(docs),
        title: name |> to_string() |> humanize()
      )

    ~H"""
    <button
      class="resource__action--link"
      phx-click={
        if @modalize,
          do:
            JS.show(
              to: "##{@task}-task-modal",
              transition: {"ease-in duration-300", "opacity-0", "opacity-100"}
            ),
          else: JS.push("task", value: %{"name" => @task}, page_loading: true, target: "#list")
      }
      ,
      data-confirm={if @modalize, do: nil, else: "Are you sure?"}
    >
      <%= @task |> to_string() |> humanize() %>
    </button>
    <%= if @modalize do %>
      <.modal id={"#{@task}-task-modal"}>
        <span class="modal__title"><%= @title %></span>
        <%= for {_lang, doc} <- @function_docs do %>
          <span class="docs"><%= doc %></span>
        <% end %>
        <.form for={Phoenix.Component.to_form(%{})} phx-submit="task" phx-target="#list">
          <input type="hidden" name="name" value={@task} />
          <%= if @extra_arg_count > 0 do %>
            <b>Arguments</b>
            <%= for num <- 1..@extra_arg_count do %>
              <div>
                <label><%= num %></label>
                <input type="text" name="args[]" />
              </div>
            <% end %>
          <% end %>
          <input type="submit" value="Execute" />
        </.form>
      </.modal>
    <% end %>
    """
  end
end
