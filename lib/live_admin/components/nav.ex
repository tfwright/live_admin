defmodule LiveAdmin.Components.Nav do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import LiveAdmin,
    only: [resource_title: 2, route_with_params: 2, trans: 1]

  @impl true
  def update(assigns, %{router: router} = socket) do
    extra_pages =
      router
      |> Phoenix.Router.routes()
      |> Enum.filter(&extra_page?(&1, assigns))
      |> Enum.sort_by(& &1.path)

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
    <div class="nav">
      <ul class="nav__list">
        <li class="nav__item--group">
          <span>
            {Keyword.fetch!(@config, :title)}
          </span>
        </li>
        <li class="nav__item--group">
          <.link navigate={@base_path}>{trans("Home")}</.link>
        </li>
        <li class="nav__item--group">
          <.nav_group
            items={@nested_resources}
            base_path={@base_path}
            current_resource={assigns[:resource]}
            config={@config}
          />
        </li>
        <%= if Enum.any?(@extra_pages) do %>
          <li class="nav__item--group">
            <%= for route <- @extra_pages do %>
              <.link navigate={route.path}>
                {humanize(route.helper)}
              </.link>
            <% end %>
          </li>
        <% end %>
        <li class="nav__item--group">
          <.link navigate={Path.join(@base_path, "session")}>
            {trans("Session")}
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  defp nav_group(assigns) do
    ~H"""
    <ul>
      <%= for {parent, children} <- Enum.sort(@items) do %>
        <%= if match?({_key, _resource}, parent) do %>
          <li class={"nav__item#{if elem(parent, 1) == @current_resource, do: "--selected"}"}>
            <.link navigate={route_with_params(assigns, resource_path: elem(parent, 0))}>
              {resource_title(elem(parent, 1), @config)}
            </.link>
          </li>
        <% else %>
          <li class="nav__item--drop">
            <input type="checkbox" id={"menu-group-#{parent}"} checked={open?(assigns, parent)} />
            <label for={"menu-group-#{parent}"}>{parent}</label>
            <.nav_group
              items={children}
              base_path={@base_path}
              current_resource={@current_resource}
              config={@config}
            />
          </li>
        <% end %>
      <% end %>
    </ul>
    """
  end

  defp open?(assigns, schema) do
    assigns.current_resource
    |> case do
      nil ->
        true

      resource ->
        resource.__live_admin_config__()
        |> Keyword.fetch!(:schema)
        |> Module.split()
        |> Enum.drop(-1)
        |> Enum.member?(schema)
    end
  end

  defp extra_page?(route, assigns) do
    valid_path?(route, assigns) and
      no_resource?(route) and
      has_non_session_keys?(route)
  end

  defp valid_path?(%{path: path}, %{base_path: base}) when is_binary(path) and is_binary(base) do
    starts_with_base?(path, base) and
      not_base_path?(path, base) and
      not_session_path?(path, base)
  end

  defp valid_path?(_, _), do: false

  defp starts_with_base?(path, base), do: String.starts_with?(path, base)

  defp not_base_path?(path, path), do: false
  defp not_base_path?(_, _), do: true

  defp not_session_path?(path, base), do: path != Path.join(base, "session")

  defp no_resource?(%{metadata: %{resource: nil}}), do: true
  defp no_resource?(%{metadata: metadata}) when not is_map_key(metadata, :resource), do: true
  defp no_resource?(_), do: false

  defp has_non_session_keys?(%{metadata: %{phoenix_live_view: {_, _, _, %{extra: extra_meta}}}})
       when is_map(extra_meta),
       do: Map.keys(extra_meta) -- [:session] != []

  defp has_non_session_keys?(_), do: false
end
