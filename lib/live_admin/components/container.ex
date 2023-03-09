defmodule LiveAdmin.Components.Container do
  use Phoenix.LiveView
  use Phoenix.HTML

  import LiveAdmin,
    only: [resource_title: 1, get_config: 3, get_resource!: 2, route_with_params: 3]

  alias __MODULE__.{Form, Index}
  alias LiveAdmin.{Resource, SessionStore}
  alias Phoenix.LiveView.JS

  @impl true
  def mount(%{"resource_id" => key}, %{"id" => session_id}, socket) do
    SessionStore.get_or_init(session_id)

    socket =
      assign(socket,
        key: key,
        resource: get_resource!(socket.assigns.resources, key),
        session_id: session_id,
        loading: !connected?(socket),
        prefix_options: get_prefix_options()
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(
        params = %{"record_id" => id},
        _uri,
        socket = %{assigns: %{resource: resource, live_action: :edit, loading: false}}
      ) do
    socket = assign_prefix(socket, params["prefix"])

    record = Resource.find(id, resource, socket.assigns.prefix)

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
        to: route_with_params(socket, socket.assigns.key, prefix: params["prefix"])
      )
    }
  end

  @impl true
  def handle_event("task", %{"task" => task}, socket) do
    task_name = String.to_existing_atom(task)

    session = SessionStore.lookup(socket.assigns.session_id)

    {m, f, a} =
      socket.assigns.resource
      |> get_config(:tasks, [])
      |> Enum.find_value(fn
        {^task_name, mfa} -> mfa
        ^task_name -> {socket.assigns.resource.schema, task_name, []}
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
    ~H"""
    <div class="resource__banner">
      <h1 class="resource__title">
        <%= resource_title(@resource) %>
      </h1>

      <div class="resource__actions">
        <div>
          <%= live_redirect("List",
            to: route_with_params(@socket, @key, prefix: @prefix),
            class: "resource__action--btn"
          ) %>
          <%= if get_config(@resource, :create_with, true) do %>
            <%= live_redirect("New",
              to: route_with_params(@socket, [@key, "new"], prefix: @prefix),
              class: "resource__action--btn"
            ) %>
          <% else %>
            <button class="resource__action--disabled" disabled="disabled">
              New
            </button>
          <% end %>
          <div class="resource__action--drop">
            <button
              class={"resource__action#{if @resource.config |> get_task_keys() |> Enum.empty?, do: "--disabled", else: "--btn"}"}
              disabled={if @resource.config |> get_task_keys() |> Enum.empty?(), do: "disabled"}
            >
              Run task
            </button>
            <nav>
              <ul>
                <%= for key <- get_task_keys(@resource.config) do %>
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
                <%= @prefix || "Set prefix" %>
              </button>
              <nav>
                <ul>
                  <%= if @prefix do %>
                    <li>
                      <a href="#" phx-click="set_prefix">clear</a>
                    </li>
                  <% end %>
                  <%= for option <- @prefix_options, to_string(option) != @prefix do %>
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
      assigns.resource
      |> get_config(:components, [])
      |> Keyword.get(:list, Index)

    assigns = assign(assigns, :mod, mod)

    ~H"""
    <.live_component
      module={@mod}
      id="list"
      resources={@resources}
      key={@key}
      resource={@resource}
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
      assigns.resource
      |> get_config(:components, [])
      |> Keyword.get(:new, Form)

    assigns = assign(assigns, :mod, mod)

    ~H"""
    <.live_component
      module={@mod}
      id="form"
      action="create"
      session_id={@session_id}
      key={@key}
      resources={@resources}
      resource={@resource}
    />
    """
  end

  def render("edit.html", assigns) do
    mod =
      assigns.resource
      |> get_config(:components, [])
      |> Keyword.get(:edit, Form)

    assigns = assign(assigns, :mod, mod)

    ~H"""
    <.live_component
      module={@mod}
      id="form"
      action="update"
      session_id={@session_id}
      key={@key}
      record={@record}
      resources={@resources}
      resource={@resource}
    />
    """
  end

  def get_prefix_options() do
    Application.get_env(:live_admin, :prefix_options)
    |> case do
      {mod, func, args} -> apply(mod, func, args)
      list when is_list(list) -> list
      nil -> []
    end
    |> Enum.sort()
  end

  def assign_prefix(socket, prefix) do
    socket.assigns.prefix_options
    |> Enum.find(
      &(to_string(&1) == (prefix || SessionStore.lookup(socket.assigns.session_id, :__prefix__)))
    )
    |> then(fn matching_prefix ->
      SessionStore.set(socket.assigns.session_id, :__prefix__, matching_prefix)

      socket = assign(socket, :prefix, matching_prefix)

      if prefix == matching_prefix do
        socket
      else
        push_redirect(socket,
          to: route_with_params(socket, socket.assigns.key, prefix: matching_prefix)
        )
      end
    end)
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
