defmodule DemoWeb.Renderer do
  def render_css(_) do
    __DIR__
    |> Path.join("../dist/css/default_overrides.css")
    |> File.read!()
  end
end
