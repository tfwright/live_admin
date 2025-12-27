defmodule LiveAdmin.Components.Container.Form.SearchSelect do
  use Phoenix.LiveComponent

  import LiveAdmin

  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns = %{options: options}, socket) do
    socket =
      socket
      |> assign(Map.delete(assigns, :options))
      |> assign(:initial_options, options)
      |> assign_async([:options], fn -> {:ok, %{options: load_options(options)}} end, reset: true)

    {:ok, socket}
  end

  @impl true
  def render(assigns = %{disabled: true}) do
    ~H"""
    <div>
      <%= if @selected_option do %>
        {elem(@selected_option, 1)}
      <% else %>
        {trans("None")}
      <% end %>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class={"search-select-container #{if @options.loading, do: "loading"}"}
      phx-hook="SearchSelect"
      id={@id}
    >
      <input
        type="hidden"
        value={elem(@selected_option, 0)}
        name={@name}
      />
      <%= if to_string(elem(@selected_option, 0)) != "" do %>
        <button
          type="button"
          phx-click={JS.push("select", value: %{key: nil}, target: @myself)}
          class="btn"
        >
          {elem(@selected_option, 1)}
        </button>
      <% else %>
        <input
          type="text"
          class="form-input"
          phx-keyup="load_options"
          phx-target={@myself}
          phx-debounce={200}
          placeholder={trans("Search") <> "..."}
        />
        <ul class="select-options">
          <%= if @options.ok? do %>
            <%= for {k, v} <- @options.result do %>
              <li phx-click={
                JS.push("select",
                  value: %{key: k},
                  target: @myself,
                  loading: "#" <> @id
                )
              }>
                {v}
              </li>
            <% end %>
            <%= if Enum.empty?(@options.result) do %>
              <li>{trans("No options")}</li>
            <% end %>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event(
        "load_options",
        %{"value" => q},
        socket = %{assigns: %{initial_options: options}}
      ) do
    socket =
      assign_async(
        socket,
        [:options],
        fn -> {:ok, %{options: load_options(options, q)}} end,
        reset: true
      )

    {:noreply, socket}
  end

  def handle_event("select", %{"key" => key}, socket) do
    socket =
      socket
      |> assign(
        :selected_option,
        Enum.find(socket.assigns.options.result, {nil, nil}, fn {k, _} -> k == key end)
      )
      |> push_event("change", %{})

    {:noreply, socket}
  end

  defp load_options(options) when is_list(options), do: options |> parse_options()
  defp load_options({m, f, a}), do: apply(m, f, [nil | a]) |> parse_options()

  defp load_options(options, q) when is_list(options),
    do: options |> parse_options() |> filter_options(q)

  defp load_options({m, f, a}, q), do: m |> apply(f, [q | a]) |> parse_options()

  defp parse_options(options = [{_, _} | _]), do: options
  defp parse_options(options), do: Enum.map(options, &{&1, &1})

  defp filter_options(options, q) when is_binary(q) do
    Enum.filter(options, fn {_, label} -> String.contains?(label, q) end)
  end
end
