defmodule LiveAdmin.Components.Container do
  use Phoenix.LiveView
  use Phoenix.HTML

  import LiveAdmin,
    only: [
      resource_title: 1,
      route_with_params: 2,
      route_with_params: 4,
      trans: 1
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

    {:ok, socket}
  end

  @impl true
  def handle_params(
        params = %{"record_id" => id},
        uri,
        socket = %{assigns: %{live_action: :edit, loading: false}}
      ) do
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
    page = String.to_integer(params["page"] || "1")

    sort = {
      String.to_existing_atom(params["sort-dir"] || "asc"),
      String.to_existing_atom(params["sort-attr"] || "id")
    }

    socket =
      socket
      |> assign(page: page)
      |> assign(sort: sort)
      |> assign(search: params["s"])
      |> assign_resource_info(uri)
      |> assign_prefix(params)
      |> assign_mod()
      |> assign_repo()

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, uri, socket),
    do:
      {:noreply,
       socket
       |> assign_resource_info(uri)
       |> assign_prefix(params)
       |> assign_mod()
       |> assign_repo()}

  @impl true
  def handle_event("set_locale", %{"locale" => locale}, socket) do
    new_session = Map.put(socket.assigns.session, :locale, locale)

    LiveAdmin.session_store().persist!(new_session)

    {:no_reply, assign(socket, :session, new_session)}
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
            to: route_with_params(@base_path, @key, [], prefix: @prefix),
            class: "resource__action--btn"
          ) %>
          <%= if @resource.__live_admin_config__(:create_with) != false do %>
            <%= live_redirect(trans("New"),
              to: route_with_params(@base_path, @key, ["new"], prefix: @prefix),
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
                    <%= link(key |> to_string() |> humanize(),
                      to: "#",
                      "data-confirm": "Are you sure?",
                      "phx-click": JS.push("task", value: %{task: key}, page_loading: true)
                    ) %>
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
                      <.link patch={route_with_params(@base_path, @key, [], prefix: "")}>
                        <%= trans("clear") %>
                      </.link>
                    </li>
                  <% end %>
                  <%= for option <- @prefix_options, to_string(option) != @prefix do %>
                    <li>
                      <.link patch={route_with_params(@base_path, @key, [], prefix: option)}>
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
                      <%= link(option,
                        to: "#",
                        "phx-click":
                          JS.push("set_locale", value: %{locale: option}, page_loading: true)
                      ) %>
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
      sort={@sort}
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

  def get_prefix_options(session) do
    Application.get_env(:live_admin, :prefix_options)
    |> case do
      {mod, func, args} -> apply(mod, func, [session | args])
      list when is_list(list) -> list
      nil -> []
    end
    |> Enum.sort()
  end

  defp assign_prefix(socket, %{"prefix" => ""}) do
    assign_and_presist_prefix(socket, nil)

    push_redirect(socket,
      to: route_with_params(socket.assigns.base_path, socket.assigns.key)
    )
  end

  defp assign_prefix(socket, %{"prefix" => prefix}) do
    socket.assigns.prefix_options
    |> Enum.find(fn option -> to_string(option) == prefix end)
    |> case do
      nil ->
        push_redirect(socket,
          to: route_with_params(socket.assigns.base_path, socket.assigns.key)
        )

      prefix ->
        assign_and_presist_prefix(socket, prefix)
    end
  end

  defp assign_prefix(socket = %{assigns: %{session: session, base_path: base_path, key: key}}, _) do
    case session.prefix do
      nil ->
        assign_and_presist_prefix(socket, nil)

      prefix ->
        push_patch(socket, to: route_with_params(base_path, key, [], prefix: prefix))
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
