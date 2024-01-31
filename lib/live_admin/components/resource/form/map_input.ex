defmodule LiveAdmin.Components.Container.Form.MapInput do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  use PhoenixHTMLHelpers

  import LiveAdmin, only: [trans: 1]

  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :values, %{})}
  end

  @impl true
  def update(assigns = %{form: form, field: field}, socket) do
    values =
      Map.get(form.params, to_string(field)) ||
        build_values_from_input_value(input_value(form, field)) ||
        %{}

    socket =
      socket
      |> assign(assigns)
      |> assign(:values, values)
      |> assign(:disabled, Enum.any?(values, fn {_, %{"value" => v}} -> is_map(v) end))

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns = %{disabled: true}) do
    ~H"""
    <div>
      <span class="resource__action--disabled">
        <pre><%= @form |> input_value(@field) |> inspect() %></pre>
      </span>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="field__map--group" phx-hook="MapInput" id={input_id(@form, @field) <> "_map_input"}>
      <div>
        <%= for {idx, %{"key" => k, "value" => v}} <- Enum.sort(@values) do %>
          <div class="field__map--row">
            <a
              href="#"
              class="button__remove"
              phx-click={
                JS.push("remove",
                  value: %{idx: idx},
                  target: @myself,
                  page_loading: true
                )
              }
            />
            <textarea
              rows="1"
              name={input_name(@form, @field) <> "[#{idx}][key]"}
              phx-debounce={200}
              placeholder={trans("Key")}
            ><%= k %></textarea>
            <textarea
              rows="1"
              name={input_name(@form, @field) <> "[#{idx}][value]"}
              phx-debounce={200}
              placeholder={trans("Value")}
            ><%= v %></textarea>
          </div>
        <% end %>
        <a
          href="#"
          phx-click={
            JS.push("add",
              target: @myself,
              page_loading: true
            )
          }
          class="button__add"
        />
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("add", _, socket) do
    socket =
      socket
      |> update(
        :values,
        &Map.put(&1, &1 |> map_size() |> to_string(), %{"key" => nil, "value" => nil})
      )
      |> push_event("change", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove", %{"idx" => idx}, socket) do
    socket =
      socket
      |> update(:values, &remove_at(&1, idx))
      |> push_event("change", %{})

    {:noreply, socket}
  end

  defp remove_at(values, idx) do
    values
    |> Map.delete(idx)
    |> Enum.with_index()
    |> Map.new(fn {{_, value}, idx} ->
      {to_string(idx), value}
    end)
  end

  defp build_values_from_input_value(nil), do: nil

  defp build_values_from_input_value(value) do
    value
    |> Enum.with_index()
    |> Map.new(fn {{k, v}, idx} ->
      {to_string(idx), %{"key" => k, "value" => v}}
    end)
  end
end
