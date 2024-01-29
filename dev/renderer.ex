defmodule DemoWeb.Renderer do
  use Phoenix.HTML

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

  def render_css(%{metadata: %{"css_theme" => "dark"}}) do
    """
    body {
      background-color: #444;
      color: #fff;
    }

    .nav {
      background-color: #444;
    }

    .resource__action--btn {
      background-color: #aaa;
      border-color: #fff;
      color: #000;
    }

    .resource__action--btn:hover {
      background-color: #ccc;
      border-color: #iii;
    }

    .resource__menu--drop nav {
      color: #000;
      background-color: #ccc;
      border-color: #iii;
    }

    .resource__header {
      background-color: #bbb;
      color: #000
    }

    .nav a:hover {
      background-color: #ccc;
    }

    .toast__container--error {
      border-color: violet;
    }

    .toast__container--success {
      border-color: chartreuse;
    }
    """
  end

  def render_css(_) do
    __DIR__
    |> Path.join("../dist/css/default_overrides.css")
    |> File.read!()
  end
end
