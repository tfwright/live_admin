defmodule LiveAdmin.Components.Session do
  use Phoenix.LiveView
  use Phoenix.HTML

  alias Ecto.Changeset
  alias LiveAdmin.Components.Container.Form.MapInput

  @impl true
  def mount(_params, %{"session_id" => session_id}, socket) do
    changeset =
      session_id
      |> LiveAdmin.session_store().load!()
      |> Changeset.change()

    {:ok, assign(socket, :changeset, changeset)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="resource__banner">
        <h1 class="resource__title">
          Session
        </h1>
      </div>

      <.form :let={f} for={@changeset} as="session" phx_submit={:save} class="resource__form">
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

  @impl true
  def handle_event("save", %{"session" => session_params}, socket) do
    session =
      socket.assigns.changeset
      |> Changeset.cast(session_params, [:metadata])
      |> Changeset.update_change(:metadata, fn indexed_metadata ->
        indexed_metadata
        |> Enum.sort_by(fn {idx, _} -> idx end)
        |> Map.new(fn {_, %{"key" => key, "value" => value}} -> {key, value} end)
      end)
      |> Changeset.apply_action!(:insert)

    LiveAdmin.session_store().persist!(session)

    {:noreply, assign(socket, :changeset, Changeset.change(session))}
  end
end
