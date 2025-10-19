defmodule LiveAdmin.Components do
  use Phoenix.Component
  use PhoenixHTMLHelpers

  import Phoenix.HTML.Form
  import LiveAdmin

  alias LiveAdmin.Components.Container.Form
  alias Phoenix.LiveView.JS

  def expand_modal(assigns) do
    assigns =
      assign(
        assigns,
        :id,
        "#{Map.fetch!(assigns.record, LiveAdmin.primary_key!(assigns.resource))}-#{assigns.field}"
      )

    ~H"""
    <div id={"field-expand-" <> @id} phx-hook="CopyField">
      <div class="modal" id={"modal-" <> @id}>
        <div
          class="modal-content"
          phx-click-away={JS.hide(to: "#modal-" <> @id)}
        >
          <div class="modal-header">
            <h3 class="modal-title">
              {record_label(@record, @resource, @config)}
              <span>{@field}</span>
            </h3>
            <button
              class="modal-close"
              phx-click={JS.hide(to: "#modal-" <> @id)}
            >
              &times;
            </button>
          </div>
          <div class="modal-body">
            <div class="detail-section-content">{@record |> Map.fetch!(@field) |> safe_render()}</div>
            <span
              class="copy-icon"
              data-clipboard-target={"#field-expand-#{@id} .detail-section-content"}
            >
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
              </svg>
            </span>
          </div>
        </div>
      </div>
      <span
        class="expand-icon"
        phx-click={JS.show(to: "#modal-" <> @id, display: "flex")}
      >
        <svg
          width="14"
          height="14"
          viewBox="0 0 14 14"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M6 6L2 2M2 2L2 4M2 2L4 2"
            stroke="currentColor"
            stroke-width="1"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M8 6L12 2M12 2L12 4M12 2L10 2"
            stroke="currentColor"
            stroke-width="1"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M6 8L2 12M2 12L2 10M2 12L4 12"
            stroke="currentColor"
            stroke-width="1"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M8 8L12 12M12 12L12 10M12 12L10 12"
            stroke="currentColor"
            stroke-width="1"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </span>
    </div>
    """
  end

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      class="modal"
      phx-capture-click={
        JS.hide(to: "##{@id}", transition: {"ease-out duration-300", "opacity-100", "opacity-0"})
      }
    >
      <div>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp list(assigns) do
    ~H"""
    <div>
      <nav>
        <ul>
          <%= if Enum.empty?(@items) && assigns[:empty_label] do %>
            <li>{render_slot(@empty_label)}</li>
          <% end %>
          <%= for item <- @items do %>
            <li>{render_slot(@inner_block, item)}</li>
          <% end %>
        </ul>
      </nav>
    </div>
    """
  end

  defp embed_fields({_, {_, %{related: schema}}}),
    do: Enum.map(schema.__schema__(:fields), &{&1, schema.__schema__(:type, &1), []})
end
