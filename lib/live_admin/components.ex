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
        "field-expand-" <>
          "#{Map.fetch!(assigns.record, LiveAdmin.primary_key!(assigns.resource))}-#{assigns.field}"
      )

    ~H"""
    <div id={@id} phx-hook="CopyField">
      <.modal id={@id <> "-modal"}>
        <:title>{record_label(@record, @resource, @config)}<span>{@field}</span></:title>
        <div class="expand-content">{@record |> Map.fetch!(@field) |> safe_render()}</div>
        <span
          class="copy-icon"
          data-clipboard-target={"##{@id}-modal .expand-content"}
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
      </.modal>
      <span
        class="expand-icon"
        phx-click={JS.show(to: "##{@id}-modal", display: "flex")}
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
    <div class="modal" id={@id}>
      <div
        class="modal-content"
        phx-click-away={JS.hide(to: "#" <> @id)}
      >
        <div class="modal-header">
          <h3 class="modal-title">
            {render_slot(@title)}
          </h3>
          <button
            class="modal-close"
            phx-click={JS.hide(to: "#" <> @id)}
          >
            &times;
          </button>
        </div>
        <div class="modal-body">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  def function_control(assigns) do
    assigns = assign(assigns, :modalize, assigns.extra_arg_count > 0 || Enum.any?(assigns.docs))

    ~H"""
    <div>
      <%= if @modalize do %>
        <.modal id={"#{@type}-#{@name}-modal"}>
          <:title>{@name |> to_string() |> humanize()}</:title>
          <.form
            for={Phoenix.Component.to_form(%{})}
            phx-submit={@type}
            phx-target={assigns[:target]}
            class="form-line"
          >
            <%= for {_lang, doc} <- @docs do %>
              <div class="docs">{doc}</div>
            <% end %>
            <input type="hidden" name="name" value={@name} />
            <%= if @extra_arg_count > 0 do %>
              <h2 class="form-title">{trans("Arguments")}</h2>
              <%= for num <- 1..@extra_arg_count do %>
                <div class="form-group">
                  <label>{num}</label>
                  <textarea class="form-textarea" name="args[]" required></textarea>
                </div>
              <% end %>
            <% end %>
            <div class="button-group">
              <button type="submit" class="btn btn-primary">{trans("Submit")}</button>
              <button type="button" class="btn btn-danger">{trans("Cancel")}</button>
            </div>
          </.form>
        </.modal>
      <% end %>
      <span
        phx-click={
          if @modalize,
            do: JS.show(to: "##{@type}-#{@name}-modal", display: "flex"),
            else: JS.push(@type, value: %{"name" => @name}, page_loading: true)
        }
        data-confirm={if @modalize, do: nil, else: trans("Are you sure you?")}
      >
        {trans(humanize(@name))}
      </span>
    </div>
    """
  end
end
