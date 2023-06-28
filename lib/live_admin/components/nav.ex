defmodule LiveAdmin.Components.Nav do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin, only: [resource_title: 1, route_with_params: 3]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="nav">
      <ul class="nav__list">
        <li class="nav__item--group"><%= @title %></li>
        <li class="nav__item--group">
          <%= live_redirect("Home", to: @socket.router.__live_admin_path__()) %>
        </li>
        <li class="nav__item--group">
          <ul>
            <%= render_dropdowns(@resources, @socket, assigns) %>
          </ul>
        </li>
        <li class="nav__item--group">
          <%= live_redirect("Session", to: Path.join(@socket.router.__live_admin_path__(), "session")) %>
        </li>
      </ul>
    </div>
    """
  end

  def render_dropdowns(resources_by_key, socket, assigns) do
    resources_by_key
    |> Enum.reduce(%{}, fn {key, resource}, groups ->
      path =
        resource.schema
        |> Module.split()
        |> case do
          list when length(list) == 1 -> list
          list -> Enum.drop(list, -1)
        end
        |> Enum.map(&Access.key(&1, %{}))

      update_in(groups, path, fn subs -> Map.put(subs, {key, resource}, %{}) end)
    end)
    |> render_resource_group(socket, assigns)
  end

  defp render_resource_group(group = %{}, socket, assigns) do
    group
    |> Enum.sort()
    |> Enum.map(fn
      {{key, resource}, %{}} ->
        content_tag :li, class: "nav__item#{if resource == assigns[:resource], do: "--selected"}" do
          resource
          |> resource_title()
          |> live_redirect(to: route_with_params(socket, key, prefix: assigns[:prefix]))
        end

      {item, subs} ->
        content_tag :li, class: "nav__item--drop" do
          open =
            assigns
            |> Map.get(:resource)
            |> case do
              %{schema: schema} ->
                schema
                |> Module.split()
                |> Enum.drop(-1)
                |> Enum.member?(item)

              _ ->
                true
            end

          [
            content_tag(:input, "", type: "checkbox", id: "menu-group-#{item}", checked: open),
            content_tag(:label, item, for: "menu-group-#{item}"),
            content_tag :ul do
              render_resource_group(subs, socket, assigns)
            end
          ]
        end
    end)
  end
end
