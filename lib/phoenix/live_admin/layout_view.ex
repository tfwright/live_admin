defmodule Phoenix.LiveAdmin.LayoutView do
  use Phoenix.HTML
  use Phoenix.View,
    namespace: Phoenix.LiveAdmin,
     root: "lib/phoenix/live_admin/templates"

  import Phoenix.LiveView.Helpers

  js_path = Path.join(__DIR__, "../../../dist/js/app.js")
  css_path = Path.join(__DIR__, "../../../dist/css/app.css")

  @external_resource js_path
  @external_resource css_path

  @app_js File.read!(js_path)
  @app_css File.read!(css_path)

  def render("app.js", _), do: @app_js
  def render("app.css", _), do: @app_css
end
