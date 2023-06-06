defmodule LiveAdmin.Components.Session.Content do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias LiveAdmin.Components.Container.Form.MapInput

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="resource__banner">
        <h1 class="resource__title">
          Session
        </h1>
      </div>

      <.form :let={f} for={@changeset} as={:session} phx-submit={:save} class="resource__form">
        <div class="field__group--disabled">
          <%= label(f, :id, class: "field__label") %>
          <%= textarea(f, :id, rows: 1, class: "field__text", disabled: true) %>
        </div>
        <div class="field__group--disabled">
          <%= label(f, :prefix, class: "field__label") %>
          <%= textarea(f, :prefix, rows: 1, class: "field__text", disabled: true) %>
        </div>
        <div class="field__group">
          <%= label(f, :metadata, class: "field__label") %>
          <.live_component module={MapInput} id="metadata" form={f} field={:metadata} form_ref={nil} />
        </div>
        <div class="form__actions">
          <%= submit("Save", class: "resource__action--btn") %>
        </div>
      </.form>
    </div>
    """
  end
end
