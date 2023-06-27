defmodule LiveAdmin.Components.Session.Content do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias Ecto.Changeset
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
          <%= label(f, :id, class: "field__label") %>
          <%= textarea(f, :id, rows: 1, class: "field__text", disabled: true) %>
        </div>
        <div class="field__group--disabled">
          <%= label(f, :prefix, class: "field__label") %>
          <%= textarea(f, :prefix, rows: 1, class: "field__text", disabled: true) %>
        </div>
        <div class="field__group">
          <%= label(f, :metadata, class: "field__label") %>
          <.live_component
            module={MapInput}
            id="metadata"
            form={f}
            field={:metadata}
            form_ref={@myself}
          />
        </div>
        <div class="form__actions">
          <%= submit("Save", class: "resource__action--btn") %>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"value" => value}, socket = %{assigns: %{changeset: changeset}}) do
    changeset =
      changeset
      |> Changeset.cast(Map.put(changeset.params || %{}, "metadata", value), [:metadata])
      |> Changeset.update_change(:metadata, &parse_map_param/1)

    {:noreply, assign(socket, changeset: changeset)}
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
      |> Changeset.cast(params["session"] || %{}, [:metadata])
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
