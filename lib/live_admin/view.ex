defmodule LiveAdmin.View do
  use Phoenix.Component
  import Phoenix.HTML
  use PhoenixHTMLHelpers

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

  @supported_primitive_types [
    :string,
    :boolean,
    :date,
    :integer,
    :naive_datetime,
    :utc_datetime,
    :id,
    :binary_id,
    :float
  ]

  embed_templates("components/layout/*")

  def render("layout.html", assigns), do: layout(assigns)

  def render_js, do: "var ENV = \"#{@env}\";" <> @app_js

  def render_css(session) do
    Application.get_env(:live_admin, :css_overrides, @default_css_overrides)
    |> case do
      {m, f, []} -> @app_css <> apply(m, f, [session])
      override_css -> @app_css <> override_css
    end
  end

  def sort_param_name(field), do: :"#{field}_sort"
  def drop_param_name(field), do: :"#{field}_drop"

  def field_class(type) when type in @supported_primitive_types, do: to_string(type)
  def field_class(:map), do: "map"
  def field_class({:array, _}), do: "array"
  def field_class({_, Ecto.Embedded, _}), do: "embed"
  def field_class({_, Ecto.Enum, _}), do: "enum"
  def field_class(_), do: "other"

  def supported_type?(type) when type in @supported_primitive_types, do: true
  def supported_type?(:map), do: true
  def supported_type?({:array, _}), do: true
  def supported_type?({_, Ecto.Embedded, _}), do: true
  def supported_type?({_, Ecto.Enum, _}), do: true
  def supported_type?(_), do: false

  def get_function_keys(resource, config, function) do
    resource
    |> LiveAdmin.fetch_config(function, config)
    |> Enum.map(fn
      {_, key, _} -> key
      {_, key} when is_atom(key) -> key
      {key, _} -> key
      key -> key
    end)
  end
end
