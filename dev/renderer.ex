defmodule DemoWeb.Renderer do
  use PhoenixHTMLHelpers

  def render_field(record, field, _session) do
    record
    |> Map.fetch!(field)
    |> case do
      bool when is_boolean(bool) ->
        if bool, do: "Yes", else: "No"
      date = %Date{} ->
        Calendar.strftime(date, "%a, %B %d %Y")
      _ ->
        record
        |> Map.fetch!(field)
        |> case do
          val when is_binary(val) -> val
          val -> inspect(val, pretty: true)
        end
    end
  end

  def render_css(_) do
    __DIR__
    |> Path.join("../dist/css/default_overrides.css")
    |> File.read!()
  end
end
