defmodule LiveAdmin.Components.Nav do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin,
    only: [resource_title: 1, route_with_params: 2, trans: 1]

  @impl true
  def render(assigns) do
    nested_resources =
      Enum.reduce(assigns.resources, %{}, fn {key, resource}, groups ->
        path =
          resource.__live_admin_config__(:schema)
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
        <li class="nav__item--group"><%= @title %></li>
        <li class="nav__item--group">
          <.link navigate={@base_path}><%= trans("Home") %></.link>
        </li>
        <li class="nav__item--group">
          <.nav_group
            items={@nested_resources}
            base_path={@base_path}
            current_resource={assigns[:resource]}
          />
        </li>
        <li class="nav__item--group">
          <.link navigate={route_with_params(assigns, resource_path: "session")}>
            <%= trans("Session") %>
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
              <%= resource_title(elem(parent, 1)) %>
            </.link>
          </li>
        <% else %>
          <li class="nav__item--drop">
            <input type="checkbox" id={"menu-group-#{parent}"} checked={open?(assigns, parent)} />
            <label for={"menu-group-#{parent}"}><%= parent %></label>
            <.nav_group items={children} base_path={@base_path} current_resource={@current_resource} />
          </li>
        <% end %>
      <% end %>
    </ul>
    """
  end

  defp open?(assigns, schema) do
    assigns
    |> Map.get(:resource)
    |> case do
      nil ->
        true

      resource ->
        resource.__live_admin_config__(:schema)
        |> Module.split()
        |> Enum.drop(-1)
        |> Enum.member?(schema)
    end
  end
end
