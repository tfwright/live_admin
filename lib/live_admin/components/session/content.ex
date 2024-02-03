defmodule LiveAdmin.Components.Session.Content do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import LiveAdmin, only: [trans: 1]

  alias Ecto.Changeset
  alias LiveAdmin.Components.Container.Form.MapInput

  @impl true
  def render(assigns) do
    ~H"""
    <div id="session-page" class="view__container" phx-hook="FormPage">
      <div class="resource__banner">
        <h1 class="resource__title">
          <%= trans("Session") %>
        </h1>
      </div>

      <.form
        :let={f}
        for={@changeset}
        as={:session}
        phx-submit={:save}
        phx-target={@myself}
        phx-change={:validate}
        class="resource__form"
      >
        <div class="field__group--disabled">
          <%= label(f, :id, trans("id"), class: "field__label") %>
          <%= textarea(f, :id, rows: 1, class: "field__text", disabled: true) %>
        </div>
        <div class="field__group--disabled">
          <%= label(f, :prefix, trans("prefix"), class: "field__label") %>
          <%= textarea(f, :prefix, rows: 1, class: "field__text", disabled: true) %>
        </div>
        <div class="field__group--disabled">
          <%= label(f, :locale, trans("locale"), class: "field__label") %>
          <%= textarea(f, :locale, rows: 1, class: "field__text", disabled: true) %>
        </div>
        <div class="field__group">
          <%= label(f, :metadata, trans("metadata"), class: "field__label") %>
          <.live_component module={MapInput} id="metadata" form={f} field={:metadata} />
        </div>
        <div class="form__actions">
          <%= submit(trans("Save"), class: "resource__action--btn") %>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"session" => params}, socket = %{assigns: %{}}) do
    changeset =
      socket.assigns.changeset
      |> Changeset.cast(params, [:metadata])
      |> Changeset.update_change(:metadata, &parse_map_param/1)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", params, socket) do
    session =
      socket.assigns.changeset
      |> Changeset.cast(params["session"] || %{}, [:metadata, :locale])
      |> Changeset.update_change(:metadata, &parse_map_param/1)
      |> Changeset.apply_action!(:insert)

    LiveAdmin.session_store().persist!(session)

    {:noreply,
     socket
     |> assign(:changeset, Changeset.change(session))
     |> push_event("success", %{msg: "Changes successfully saved"})}
  end

  defp parse_map_param(param = %{}) do
    param
    |> Enum.sort_by(fn {idx, _} -> idx end)
    |> Map.new(fn {_, %{"key" => key, "value" => value}} -> {key, value} end)
  end
end
