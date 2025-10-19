defmodule LiveAdmin.Components.Nav do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import LiveAdmin,
    only: [resource_title: 2, route_with_params: 2, trans: 1]

  @impl true
  def update(assigns, socket) do
    base_path = assigns.base_path

    extra_pages =
      socket.router
      |> Phoenix.Router.routes()
      |> Enum.filter(fn r ->
        match?(
          %{
            metadata: %{
              phoenix_live_view: {_, _, _, %{extra: %{session: {_, _, [^base_path, _]}}}}
            }
          },
          r
        ) && is_nil(r.metadata[:resource]) &&
          !String.match?(r.helper, ~r/(home|session)/)
      end)

    socket =
      socket
      |> assign(assigns)
      |> assign(extra_pages: extra_pages)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    nested_resources =
      Enum.reduce(assigns.resources, %{}, fn {key, resource}, groups ->
        path =
          resource
          |> LiveAdmin.fetch_config(:schema, assigns.config)
          |> Module.split()
          |> case do
            list when length(list) == 1 -> list
            list -> Enum.drop(list, -1)
          end
          |> Enum.map(&Access.key(&1, %{}))

        update_in(groups, path, fn subs -> Map.put(subs, {key, resource}, %{}) end)
      end)

    assigns = assign(assigns, :nested_resources, nested_resources)

    ~H"""
    <nav>
      <div class="nav-section">
        <div class="nav-section-title">Admin</div>
        <.link navigate={@base_path} class="nav-item">
          <span class="nav-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="3" width="7" height="7" />
              <rect x="14" y="3" width="7" height="7" />
              <rect x="14" y="14" width="7" height="7" />
              <rect x="3" y="14" width="7" height="7" />
            </svg>
          </span>
          {trans("Dashboard")}
        </.link>
        <.link navigate={Path.join(@base_path, "session")} class="nav-item">
          <span class="nav-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
              <circle cx="12" cy="7" r="4" />
            </svg>
          </span>
          <span>{trans("Session")}</span>
        </.link>
      </div>
      <div class="nav-section">
        <div class="nav-section-title">Resources</div>
        <.nav_group
          items={@nested_resources}
          base_path={@base_path}
          current_resource={assigns[:resource]}
          config={@config}
        />
      </div>
      <%= if Enum.any?(@extra_pages) do %>
        <div class="nav-section">
          <div class="nav-section-title">Pages</div>
          <%= for route <- @extra_pages do %>
            <.link navigate={route.path} class="nav-item">
              <span class="nav-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
                  <line x1="16" y1="2" x2="16" y2="6" />
                  <line x1="8" y1="2" x2="8" y2="6" />
                  <line x1="3" y1="10" x2="21" y2="10" />
                </svg>
              </span>
              <span>{humanize(route.helper)}</span>
            </.link>
          <% end %>
        </div>
      <% end %>
    </nav>
    """
  end

  defp nav_group(assigns) do
    ~H"""
    <div>
      <%= for {parent, children} <- Enum.sort(@items) do %>
        <%= if match?({_key, _resource}, parent) do %>
          <.link
            navigate={route_with_params(assigns, resource_path: elem(parent, 0))}
            class={"nav-item #{if elem(parent, 1) == @current_resource, do: "active"}"}
          >
            {resource_title(elem(parent, 1), @config)}
          </.link>
        <% else %>
          <input
            type="checkbox"
            id={"#{parent}-toggle"}
            class="nav-toggle-input"
            checked={open?(assigns, parent)}
          />
          <label for={"#{parent}-toggle"} class="nav-toggle-label">
            <span class="nav-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                <polyline points="14 2 14 8 20 8"></polyline>
                <line x1="16" y1="13" x2="8" y2="13"></line>
                <line x1="16" y1="17" x2="8" y2="17"></line>
                <polyline points="10 9 9 9 8 9"></polyline>
              </svg>
            </span>
            <span>{parent}</span>
            <span class="nav-item-expand">▼</span>
          </label>
          <div class="nav-subitems">
            <.nav_group
              items={children}
              base_path={@base_path}
              current_resource={@current_resource}
              config={@config}
            />
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp open?(assigns, schema) do
    assigns.current_resource
    |> case do
      nil ->
        false

      resource ->
        resource.__live_admin_config__()
        |> Keyword.fetch!(:schema)
        |> Module.split()
        |> Enum.drop(-1)
        |> Enum.member?(schema)
    end
  end
end
