defmodule Phoenix.LiveAdmin.View do
  use Phoenix.HTML

  use Phoenix.View,
    namespace: Phoenix.LiveAdmin,
    root: __DIR__

  import Phoenix.LiveAdmin, only: [resource_title: 3, resource_path: 2]
  import Phoenix.LiveView.Helpers

  js_path = Path.join(__DIR__, "../../../dist/js/app.js")
  css_path = Path.join(__DIR__, "../../../dist/css/app.css")

  @external_resource js_path
  @external_resource css_path

  @app_js File.read!(js_path)
  @app_css File.read!(css_path)

  def render("app.js", _), do: @app_js
  def render("app.css", _), do: @app_css

  def render_nav_menu(resources, socket, base_path) do
    Enum.reduce(resources, %{}, fn resource = {_, {schema, _}}, groups ->
      path =
        schema
        |> resource_path(base_path)
        |> case do
          list when length(list) == 1 -> list
          list -> Enum.drop(list, -1)
        end
        |> Enum.map(&Access.key(&1, %{}))

      update_in(groups, path, &Map.put(&1, resource, %{}))
    end)
    |> render_nav_group(socket, base_path)
  end

  def build_route(socket, args),
    do: apply(socket.router.__helpers__(), :resource_path, [socket | args])

  defp render_nav_group(group = %{}, socket, base_path) do
    group
    |> Enum.sort()
    |> Enum.map(fn
      {{key, {schema, config}}, %{}} ->
        content_tag :li, class: "nav__item" do
          live_redirect(resource_title(schema, config, base_path),
            to: build_route(socket, [:list, key])
          )
        end

      {item, subs} ->
        content_tag :li, class: "nav__item--drop" do
          [
            content_tag(:input, "", type: "checkbox", id: "menu-group-#{item}"),
            content_tag(:label, item, for: "menu-group-#{item}"),
            content_tag :ul, class: "nav__group" do
              render_nav_group(subs, socket, base_path)
            end
          ]
        end
    end)
  end
end
