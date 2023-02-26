defmodule LiveAdmin.View do
  use Phoenix.HTML

  use Phoenix.View,
    namespace: LiveAdmin,
    root: __DIR__

  import LiveAdmin, only: [resource_title: 1, resource_path: 2]
  import Phoenix.LiveView.Helpers

  js_path = Path.join(__DIR__, "../../dist/js/app.js")
  css_path = Path.join(__DIR__, "../../dist/css/app.css")
  default_css_overrides_path = Path.join(__DIR__, "../../dist/css/default_overrides.css")

  @external_resource js_path
  @external_resource css_path
  @external_resource default_css_overrides_path

  @app_js File.read!(js_path)
  @app_css File.read!(css_path)
  @default_css_overrides File.read!(default_css_overrides_path)

  @env Mix.env()

  def render("app.js", _), do: "var ENV = \"#{@env}\";" <> @app_js

  def render("app.css", _),
    do: @app_css <> Application.get_env(:live_admin, :css_overrides, @default_css_overrides)

  def route_with_params(socket, segments, params \\ %{}) do
    params =
      Enum.flat_map(params, fn
        {:prefix, nil} -> []
        pair -> [pair]
      end)

    path =
      segments
      |> List.wrap()
      |> Enum.map(&Phoenix.Param.to_param/1)
      |> Path.join()

    encoded_params =
      params
      |> Enum.into(%{})
      |> Enum.empty?()
      |> case do
        true -> ""
        false -> "?" <> Plug.Conn.Query.encode(params)
      end

    socket.router.__live_admin_path__()
    |> Path.join(path)
    |> Kernel.<>(encoded_params)
  end

  def render_field(record, field, _) do
    record
    |> Map.fetch!(field)
    |> case do
      val when is_binary(val) -> val
      val -> inspect(val)
    end
  end

  def render_nav_menu(resources_by_key, socket, base_path, assigns) do
    resources_by_key
    |> Enum.reduce(%{}, fn {key, resource}, groups ->
      path =
        resource
        |> resource_path(base_path)
        |> case do
          list when length(list) == 1 -> list
          list -> Enum.drop(list, -1)
        end
        |> Enum.map(&Access.key(&1, %{}))

      update_in(groups, path, fn subs -> Map.put(subs, {key, resource}, %{}) end)
    end)
    |> render_nav_group(socket, base_path, assigns)
  end

  defp render_nav_group(group = %{}, socket, base_path, assigns) do
    group
    |> Enum.sort()
    |> Enum.map(fn
      {{key, resource}, %{}} ->
        content_tag :li, class: "nav__item#{if resource == assigns[:resource], do: "--selected"}" do
          resource
          |> resource_title()
          |> live_redirect(to: route_with_params(socket, key, prefix: assigns["prefix"]))
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
            content_tag :ul, class: "nav__group" do
              render_nav_group(subs, socket, base_path, assigns)
            end
          ]
        end
    end)
  end
end
