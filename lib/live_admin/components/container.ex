defmodule LiveAdmin.Components.Container do
  use Phoenix.LiveView
  use Phoenix.HTML

  import LiveAdmin,
    only: [
      resource_title: 1,
      route_with_params: 1,
      route_with_params: 2,
      record_label: 2,
      trans: 1,
      trans: 2
    ]

  alias LiveAdmin.Resource
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, %{"components" => components}, socket) do
    socket =
      assign(socket,
        default_mod: Map.fetch!(components, socket.assigns.live_action),
        loading: !connected?(socket),
        prefix_options: get_prefix_options(socket.assigns.session)
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
      |> assign_prefix(params)
      |> assign_mod()
      |> assign_repo()

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
      |> assign_prefix(params)
      |> assign_mod()
      |> assign_repo()

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, uri, socket = %{assigns: %{live_action: :new}}),
    do:
      {:noreply,
       socket
       |> assign_resource_info(uri)
       |> assign_prefix(params)
       |> assign_mod()
       |> assign_repo()}

  def handle_params(_, _, socket), do: {:noreply, socket}

  @impl true
  def handle_event(
        "delete",
        %{"id" => id},
        %{
          assigns: %{
            resource: resource,
            session: session
          }
        } = socket
      ) do
    socket =
      id
      |> Resource.find!(resource, socket.assigns.prefix, socket.assigns.repo)
      |> Resource.delete(resource, session, socket.assigns.repo)
      |> case do
        {:ok, record} ->
          socket
          |> put_flash(
            :info,
            trans("Deleted %{label}", inter: [label: record_label(record, resource)])
          )
          |> push_navigate(to: route_with_params(socket.assigns))

        {:error, _} ->
          push_event(socket, "error", %{
            msg: trans("Delete failed!")
          })
      end

    {:noreply, socket}
  end

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
  def handle_event(
        "action",
        params = %{"action" => action},
        socket = %{assigns: %{resource: resource, prefix: prefix, repo: repo}}
      ) do
    record = socket.assigns[:record] || Resource.find!(params["id"], resource, prefix, repo)

    action_name = String.to_existing_atom(action)

    {m, f, a} =
      :actions
      |> resource.__live_admin_config__()
      |> Enum.find_value(fn
        {^action_name, mfa} -> mfa
        ^action_name -> {resource, action_name, []}
        _ -> false
      end)

    socket =
      case apply(m, f, [record, socket.assigns.session] ++ a) do
        {:ok, record} ->
          socket
          |> push_event("success", %{
            msg: trans("Successfully completed %{action}", inter: [action: action])
          })
          |> assign(:record, record)

        {:error, error} ->
          push_event(
            socket,
            "error",
            trans("%{action} failed: %{error}",
              inter: [
                action: action,
                error: error
              ]
            )
          )
      end

    {:noreply, socket}
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
            msg: "Successfully completed #{task}: #{inspect(result)}"
          })

        {:error, error} ->
          push_event(socket, "error", %{msg: "#{task} failed: #{error}"})
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
          <div class="resource__action--drop">
            <button
              class={"resource__action#{if @resource |> get_task_keys() |> Enum.empty?, do: "--disabled", else: "--btn"}"}
              disabled={if @resource |> get_task_keys() |> Enum.empty?(), do: "disabled"}
            >
              <%= trans("Run task") %>
            </button>
            <nav>
              <ul>
                <%= for key <- get_task_keys(@resource) do %>
                  <li>
                    <button
                      class="resource__action--link"
                      phx-click={JS.push("task", value: %{task: key}, page_loading: true)}
                      ,
                      data-confirm="Are you sure?"
                    >
                      <%= key |> to_string() |> humanize() %>
                    </button>
                  </li>
                <% end %>
              </ul>
            </nav>
          </div>
          <%= if @prefix_options do %>
            <div id="prefix-select" class="resource__action--drop">
              <button class="resource__action--btn">
                <%= @prefix || trans("Set prefix") %>
              </button>
              <nav>
                <ul>
                  <%= if @prefix do %>
                    <li>
                      <button
                        class="resource__action--link"
                        phx-click={JS.push("clear_prefix", page_loading: true)}
                      >
                        <%= trans("clear") %>
                      </button>
                    </li>
                  <% end %>
                  <%= for option <- @prefix_options, to_string(option) != @prefix do %>
                    <li>
                      <.link patch={route_with_params(assigns, params: [prefix: option])}>
                        <%= option %>
                      </.link>
                    </li>
                  <% end %>
                </ul>
              </nav>
            </div>
          <% end %>
          <%= if LiveAdmin.use_i18n? do %>
            <div id="locale-select" class="resource__action--drop">
              <button class="resource__action--btn">
                <%= @session.locale || "Set locale" %>
              </button>
              <nav>
                <ul>
                  <%= for option <- LiveAdmin.gettext_backend().locales(), to_string(option) != @session.locale do %>
                    <li>
                      <button
                        class="resource__action--link"
                        phx-click={
                          JS.push("set_locale", value: %{locale: option}, page_loading: true)
                        }
                      >
                        <%= option %>
                      </button>
                    </li>
                  <% end %>
                </ul>
              </nav>
            </div>
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
      session={@session}
      key={@key}
      base_path={@base_path}
    />
    """
  end

  def get_prefix_options(session) do
    Application.get_env(:live_admin, :prefix_options)
    |> case do
      {mod, func, args} -> apply(mod, func, [session | args])
      list when is_list(list) -> list
      nil -> []
    end
    |> Enum.sort()
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

    assign(socket, :repo, repo)
  end
end
