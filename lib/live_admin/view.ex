defmodule LiveAdmin.View do
  use Phoenix.Component
  use Phoenix.HTML

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

  embed_templates("components/layout/*")

  def render("layout.html", assigns), do: layout(assigns)

  def render_js, do: "var ENV = \"#{@env}\";" <> @app_js

  def render_css(session) do
    Application.get_env(:live_admin, :css_overrides, @default_css_overrides)
    |> case do
      {m, f, a} -> @app_css <> apply(m, f, [session | a])
      override_css -> @app_css <> override_css
    end
  end
end
