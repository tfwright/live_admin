defmodule LiveAdmin.Components do
  use Phoenix.Component

  slot(:inner_block, required: true)

  attr(:label, :string, required: true)
  attr(:disabled, :boolean, default: false)
  attr(:items, :list, default: [])
  attr(:orientation, :atom, values: [:up, :down], default: :down)
  attr(:id, :string, default: nil)

  def dropdown(assigns) do
    ~H"""
    <div id={@id} class="resource__action--drop">
      <%= if @orientation == :up do %>
        <.list items={@items} inner_block={@inner_block} />
      <% end %>
      <button
        class={"resource__action#{if @disabled, do: "--disabled", else: "--btn"}"}
        disabled={if @disabled, do: "disabled"}
      >
        <%= @label %>
      </button>
      <%= if @orientation == :down do %>
        <.list items={@items} inner_block={@inner_block} />
      <% end %>
    </div>
    """
  end

  defp list(assigns) do
    ~H"""
    <div>
      <nav>
        <ul>
          <%= for item <- @items do %>
            <li><%= render_slot(@inner_block, item) %></li>
          <% end %>
        </ul>
      </nav>
    </div>
    """
  end
end
