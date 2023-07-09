defmodule LiveAdmin.Components.Nav do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin,
    only: [resource_title: 1, route_with_params: 2, trans: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="nav">
      <ul class="nav__list">
        <li class="nav__item--group"><%= @title %></li>
        <li class="nav__item--group">
          <%= live_redirect(trans("Home"), to: @base_path) %>
        </li>
        <li class="nav__item--group">
          <ul>
            <%= render_dropdowns(assigns) %>
          </ul>
        </li>
        <li class="nav__item--group">
          <%= live_redirect(trans("Session"),
            to: route_with_params(assigns, resource_path: "session")
          ) %>
        </li>
      </ul>
    </div>
    """
  end

  def render_dropdowns(assigns) do
    assigns.resources
    |> Enum.reduce(%{}, fn {key, resource}, groups ->
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
    |> render_resource_group(assigns)
  end

  defp render_resource_group(group = %{}, assigns) do
    group
    |> Enum.sort()
    |> Enum.map(fn
      {{key, resource}, %{}} ->
        content_tag :li, class: "nav__item#{if resource == assigns[:resource], do: "--selected"}" do
          resource
          |> resource_title()
          |> live_redirect(
            to: route_with_params(assigns, resource_path: key, prefix: assigns[:prefix])
          )
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
            content_tag(:ul, do: render_resource_group(subs, assigns))
          ]
        end
    end)
  end
end
