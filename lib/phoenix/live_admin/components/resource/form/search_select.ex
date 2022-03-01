defmodule Phoenix.LiveAdmin.Components.Resource.Form.SearchSelect do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import Phoenix.LiveAdmin, only: [record_label: 2]
  import Phoenix.LiveAdmin.Components.Resource, only: [get_resource!: 3]
  import Phoenix.LiveAdmin.Components.Resource.Index, only: [list: 3]

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :options, [])}
  end

  @impl true
  def update(assigns = %{resource: resource, form: form, field: field}, socket) do
    selected_option =
      form
      |> input_value(field)
      |> case do
        nil -> nil
        "" -> nil
        id -> get_resource!(id, resource, Ecto.get_meta(form.data, :prefix))
      end

    socket =
      socket
      |> assign(assigns)
      |> assign(:selected_option, selected_option)

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
        <%= if @selected_option do %>
          <%= record_label(@selected_option, @config) %>
        <% else %>
          None
        <% end %>
      </span>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="resource__action--drop">
        <%= hidden_input @form, @field, disabled: @disabled %>
        <%= if @selected_option do %>
          <a href="#" phx-click="put_change" phx-value-field={@field} phx-target={@form_ref} class="resource__action--btn">
          <svg xmlns="http://www.w3.org/2000/svg"
            class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 30 30">
            <path d="M 7 4 C 6.744125 4 6.4879687 4.0974687 6.2929688 4.2929688 L 4.2929688 6.2929688 C 3.9019687 6.6839688 3.9019687 7.3170313 4.2929688 7.7070312 L 11.585938 15 L 4.2929688 22.292969 C 3.9019687 22.683969 3.9019687 23.317031 4.2929688 23.707031 L 6.2929688 25.707031 C 6.6839688 26.098031 7.3170313 26.098031 7.7070312 25.707031 L 15 18.414062 L 22.292969 25.707031 C 22.682969 26.098031 23.317031 26.098031 23.707031 25.707031 L 25.707031 23.707031 C 26.098031 23.316031 26.098031 22.682969 25.707031 22.292969 L 18.414062 15 L 25.707031 7.7070312 C 26.098031 7.3170312 26.098031 6.6829688 25.707031 6.2929688 L 23.707031 4.2929688 C 23.316031 3.9019687 22.682969 3.9019687 22.292969 4.2929688 L 15 11.585938 L 7.7070312 4.2929688 C 7.5115312 4.0974687 7.255875 4 7 4 z"></path></svg>
            <%= record_label(@selected_option, @config) %>
          </a>
        <% else %>
          <%= text_input :search, :select, disabled: @disabled, placeholder: "Search", phx_focus: "load_options", phx_keyup: "load_options", phx_target: @myself, phx_debounce: 200 %>
        <% end %>
        <nav>
          <ul>
            <%= if Enum.empty?(@options) do %>
              <li>No options</li>
            <% end %>
            <%= for option <- @options, option.id != input_value(@form, @field) do %>
              <li>
                <a href="#" phx-click="put_change" phx-value-field={@field} phx-value-value={option.id} phx-target={@form_ref}>
                  <%= record_label(option, @config) %>
                </a>
              </li>
            <% end %>
          </ul>
        </nav>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "load_options",
        %{"value" => q},
        socket = %{assigns: %{resource: resource, config: config}}
      ) do
    options =
      resource
      |> list(config, search: q)
      |> elem(0)

    {:noreply, assign(socket, :options, options)}
  end
end
