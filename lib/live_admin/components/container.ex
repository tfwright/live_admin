defmodule LiveAdmin.Components.Container do
  use Phoenix.LiveView
  use Phoenix.HTML

  import LiveAdmin,
    only: [resource_title: 2, get_config: 3, get_resource: 1]

  alias __MODULE__.{Form, Index}
  alias LiveAdmin.{Resource, SessionStore}

  @impl true
  def mount(%{"resource_id" => key}, %{"id" => session_id}, socket) do
    SessionStore.get_or_init(session_id)

    socket =
      assign(socket,
        key: key,
        session_id: session_id,
        loading: !connected?(socket)
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(
        params = %{"record_id" => id},
        _uri,
        socket = %{assigns: %{live_action: :edit, loading: false}}
      ) do
    socket = assign_prefix(socket, params["prefix"])

    record = Resource.find!(id, get_resource(socket.assigns), socket.assigns.prefix)

    socket = assign(socket, record: record)

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, _uri, socket = %{assigns: %{live_action: :list, loading: false}}) do
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
      |> assign_prefix(params["prefix"])

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, _uri, socket), do: {:noreply, assign_prefix(socket, params["prefix"])}

  @impl true
  def handle_event("set_prefix", params, socket) do
    prefix = params["prefix"]

    if is_nil(prefix) do
      SessionStore.set(socket.assigns.session_id, :__prefix__, prefix)
    end

    {
      :noreply,
      push_redirect(socket,
        to: route_with_params(socket, [:list, socket.assigns.key], prefix: params["prefix"])
      )
    }
  end

  @impl true
  def handle_event("task", %{"task" => task}, socket) do
    task_name = String.to_existing_atom(task)

    session = SessionStore.lookup(socket.assigns.session_id)

    resource = get_resource(socket.assigns)

    {m, f, a} =
      resource.config
      |> get_config(:tasks, [])
      |> Enum.find_value(fn
        {^task_name, mfa} -> mfa
        ^task_name -> {resource.schema, task_name, []}
      end)

    socket =
      case apply(m, f, [session] ++ a) do
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
    assigns = assign(assigns, :resource, get_resource(assigns))

    ~H"""
    <div class="resource__banner">
      <h1 class="resource__title">
        <%= resource_title(@resource, @base_path) %>
      </h1>

      <div class="resource__actions">
        <div>
          <%= live_redirect("List",
            to: route_with_params(@socket, [:list, @key], prefix: @prefix),
            class: "resource__action--btn"
          ) %>
          <%= if get_config(@resource, :create_with, true) do %>
            <%= live_redirect("New",
              to: route_with_params(@socket, [:new, @key], prefix: @prefix),
              class: "resource__action--btn"
            ) %>
          <% end %>
          <div class="resource__action--drop">
            <button class="resource__action--btn">Run task</button>
            <nav>
              <ul>
              <%= for key <- get_task_keys(@resource.config) do %>
                <li>
                  <%= link(key |> to_string() |> humanize(),
                    to: "#",
                    "data-confirm": "Are you sure?",
                    "phx-click": "task",
                    "phx-value-task": key
                  ) %>
                </li>
              <% end %>
              </ul>
            </nav>
          </div>
          <%= if Application.get_env(:live_admin, :prefix_options) do %>
            <div class="resource__action--drop">
              <button class="resource__action--btn">
                <%= @prefix || "Set prefix" %>
              </button>
              <nav>
                <ul>
                  <%= if @prefix do %>
                    <li>
                      <a href="#" phx-click="set_prefix">clear</a>
                    </li>
                  <% end %>
                  <%= for option <- get_prefix_options!(), to_string(option) != @prefix do %>
                    <li>
                      <a href="#" phx-click="set_prefix" phx-value-prefix={option}><%= option %></a>
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
    mod =
      assigns.resource.config
      |> get_config(:components, [])
      |> Keyword.get(:list, Index)

    ~H"""
    <.live_component
      module={mod}
      id="list"
      socket={@socket}
      resources={@resources}
      key={@key}
      page={@page}
      sort={@sort}
      search={@search}
      prefix={@prefix}
      session_id={@session_id}
    />
    """
  end

  def render("new.html", assigns) do
    mod =
      assigns.resource.config
      |> get_config(:components, [])
      |> Keyword.get(:new, Form)

    ~H"""
    <.live_component
      module={mod}
      id="form"
      action="create"
      session_id={@session_id}
      key={@key}
      resources={@resources}
    />
    """
  end

  def render("edit.html", assigns) do
    mod =
      assigns.resource.config
      |> get_config(:components, [])
      |> Keyword.get(:edit, Form)

    ~H"""
    <.live_component
      module={mod}
      id="form"
      action="update"
      session_id={@session_id}
      key={@key}
      record={@record}
      resources={@resources}
    />
    """
  end

  def route_with_params(socket, segments, params \\ %{}) do
    params =
      Enum.flat_map(params, fn
        {:prefix, nil} -> []
        pair -> [pair]
      end)

    apply(socket.router.__helpers__(), :resource_path, [socket] ++ segments ++ [params])
  end

  def get_prefix_options!() do
    Application.fetch_env!(:live_admin, :prefix_options)
    |> case do
      {mod, func, args} -> apply(mod, func, args)
      list when is_list(list) -> list
    end
    |> Enum.sort()
  end

  def assign_prefix(_, prefix \\ nil)

  def assign_prefix(socket, nil) do
    case SessionStore.lookup(socket.assigns.session_id, :__prefix__) do
      nil ->
        assign(socket, :prefix, nil)

      prefix ->
        socket
        |> assign(:prefix, prefix)
        |> push_redirect(
          to: route_with_params(socket, [:list, socket.assigns.key], prefix: prefix)
        )
    end
  end

  def assign_prefix(socket, prefix) do
    SessionStore.set(socket.assigns.session_id, :__prefix__, prefix)

    assign(socket, :prefix, prefix)
  end

  defp get_task_keys(config) do
    config
    |> Map.get(:tasks, [])
    |> Enum.map(fn
      {key, _} -> key
      key -> key
    end)
  end
end
