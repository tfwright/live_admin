defmodule LiveAdmin.Components.Container do
  use Phoenix.LiveView
  use Phoenix.HTML

  import LiveAdmin,
    only: [
      resource_title: 1,
      route_with_params: 1,
      route_with_params: 2,
      trans: 1,
      trans: 2
    ]

  import LiveAdmin.Components

  alias LiveAdmin.Resource
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, %{"components" => components}, socket) do
    socket =
      assign(socket,
        default_mod: Map.fetch!(components, socket.assigns.live_action),
        loading: !connected?(socket)
      )

    Process.send_after(self(), :clear_flash, 2000)

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
      Resource.find(id, socket.assigns.resource, socket.assigns.prefix, socket.assigns.repo)

    socket = assign(socket, record: record)

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, uri, socket = %{assigns: %{live_action: :list, loading: false}}) do
    socket =
      socket
      |> assign(page: String.to_integer(params["page"] || "1"))
      |> assign(sort_attr: String.to_existing_atom(params["sort-attr"] || "id"))
      |> assign(sort_dir: String.to_existing_atom(params["sort-dir"] || "asc"))
      |> assign(search: params["s"])
      |> assign_resource_info(uri)
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

  @impl true
  def handle_event("clear_prefix", _, socket) do
    new_session = Map.put(socket.assigns.session, :prefix, nil)

    LiveAdmin.session_store().persist!(new_session)

    socket = assign(socket, prefix: nil, session: new_session)

    {:noreply, push_redirect(socket, to: route_with_params(socket.assigns))}
  end

  @impl true
  def handle_event("task", %{"task" => task}, socket) do
    task_name = String.to_existing_atom(task)

    {m, f, a} =
      :tasks
      |> socket.assigns.resource.__live_admin_config__()
      |> Enum.find_value(fn
        {^task_name, mfa} -> mfa
        ^task_name -> {socket.assigns.resource, task_name, []}
      end)

    socket =
      case apply(m, f, [socket.assigns.session] ++ a) do
        {:ok, result} ->
          push_event(socket, "success", %{
            msg:
              trans("%{task} succeeded: %{result}",
                inter: [
                  task: task,
                  result: result
                ]
              )
          })

        {:error, error} ->
          push_event(socket, "error", %{
            msg:
              trans("%{task} failed: %{error}",
                inter: [
                  task: task,
                  error: error
                ]
              )
          })
      end

    {:noreply, socket}
  end

  def render(assigns = %{loading: true}), do: ~H"
"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="resource__banner">
      <h1 class="resource__title">
        <%= resource_title(@resource) %>
      </h1>

      <div class="resource__actions">
        <div>
          <%= live_redirect(trans("List"),
            to: route_with_params(assigns, params: [prefix: @prefix]),
            class: "resource__action--btn"
          ) %>
          <%= if @resource.__live_admin_config__(:create_with) != false do %>
            <%= live_redirect(trans("New"),
              to: route_with_params(assigns, segments: ["new"], params: [prefix: @prefix]),
              class: "resource__action--btn"
            ) %>
          <% else %>
            <button class="resource__action--disabled" disabled="disabled">
              <%= trans("New") %>
            </button>
          <% end %>
          <.dropdown
            :let={task}
            label={trans("Run task")}
            items={get_task_keys(@resource)}
            disabled={@resource |> get_task_keys() |> Enum.empty?()}
          >
            <button
              class="resource__action--link"
              phx-click={JS.push("task", value: %{task: task}, page_loading: true)}
              ,
              data-confirm="Are you sure?"
            >
              <%= task |> to_string() |> humanize() %>
            </button>
          </.dropdown>
          <%= if Enum.any?(@prefix_options) do %>
            <%= if @prefix do %>
              <.dropdown :let={clear} id="prefix-select" label={@prefix} items={[trans("clear")]}>
                <button
                  class="resource__action--link"
                  phx-click={JS.push("clear_prefix", page_loading: true)}
                >
                  <%= clear %>
                </button>
              </.dropdown>
            <% else %>
              <.dropdown
                :let={prefix}
                id="prefix-select"
                label={trans("Set prefix")}
                items={Enum.filter(@prefix_options, &(to_string(&1) != @prefix))}
              >
                <.link navigate={route_with_params(assigns, params: [prefix: prefix])}>
                  <%= prefix %>
                </.link>
              </.dropdown>
            <% end %>
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
    />
    """
  end

  defp assign_prefix(socket, %{"prefix" => prefix}) do
    socket.assigns.prefix_options
    |> Enum.find(fn option -> to_string(option) == prefix end)
    |> case do
      nil ->
        push_redirect(socket, to: route_with_params(socket.assigns))

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

  defp get_task_keys(resource) do
    :tasks
    |> resource.__live_admin_config__()
    |> Enum.map(fn
      {key, _} -> key
      key -> key
    end)
  end

  defp assign_resource_info(socket, uri) do
    %URI{host: host, path: path} = URI.parse(uri)

    %{resource: {key, mod}} = Phoenix.Router.route_info(socket.router, "GET", path, host)

    assign(socket, key: key, resource: mod)
  end

  defp assign_mod(
         socket = %{assigns: %{resource: resource, live_action: action, default_mod: default}}
       ) do
    mod =
      :components
      |> resource.__live_admin_config__()
      |> Keyword.get(action, default)

    assign(socket, :mod, mod)
  end

  defp assign_repo(socket = %{assigns: %{resource: resource, default_repo: default}}) do
    repo =
      :ecto_repo
      |> resource.__live_admin_config__()
      |> Kernel.||(default)
      |> Kernel.||(raise "no repo configured")

    prefix_options =
      if function_exported?(repo, :prefixes, 0) do
        repo.prefixes()
      else
        []
      end

    assign(socket, repo: repo, prefix_options: prefix_options)
  end
end
