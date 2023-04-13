defmodule LiveAdmin.Components.Container.Form.MapInput do
  use Phoenix.LiveComponent
  use Phoenix.HTML

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
    <div class="field__map">
      <%= for {idx, %{"key" => k, "value" => v}} <- Enum.sort(@values) do %>
        <div>
          <a
            phx-click={
              JS.push("validate",
                value: %{field: @field, value: remove_at(@values, idx)},
                target: @form_ref,
                page_loading: true
              )
            }
            href="#"
            class="button__remove"
          />
          <input type="text" name={input_name(@form, @field) <> "[#{idx}][key]"} value={k} />
          <input type="text" name={input_name(@form, @field) <> "[#{idx}][value]"} value={v} />
        </div>
      <% end %>
      <div class="form__actions">
        <a phx-click={JS.push("add", target: @myself)} href="#" class="resource__action--btn">
          New
        </a>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("add", _, socket) do
    {:noreply,
     update(
       socket,
       :values,
       &Map.put(&1, &1 |> map_size() |> to_string(), %{"key" => nil, "value" => nil})
     )}
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
