defmodule LiveAdmin.Components.Session.Content do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import LiveAdmin

  alias Ecto.Changeset

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="content-header">
        <h1 class="content-title">
          {trans("Session")}
        </h1>
      </div>

      <div class="content-card">
        <div class="card-section">
          <div class="edit-view">
            <.form
              :let={f}
              for={@changeset}
              as={:session}
              phx-submit={:save}
              phx-target={@myself}
              phx-change={:validate}
            >
              <div class="form-grid">
                <div class="form-field">
                  <div class="form-label">{trans("ID")}</div>
                  <textarea name={f[:id].name} class="form-textarea" disabled>{f[:id].value}</textarea>
                </div>

                <div class="form-field">
                  <div class="form-label">{trans("Locale")}</div>
                  <textarea name={f[:locale].name} class="form-textarea" disabled>{f[:locale].value}</textarea>
                </div>

                <div class="form-field">
                  <div class="form-label">{trans("Metadata")}</div>
                  <textarea name={f[:metadata].name} class="form-textarea" disabled>{inspect(f[:metadata].value, pretty: true)}</textarea>
                </div>

                <div class="form-field">
                  <div class="form-label">{trans("Index page size")}</div>
                  <textarea name={f[:index_page_size].name} class="form-textarea">{f[:index_page_size].value}</textarea>
                </div>
              </div>
              <div class="form-actions">
                <input type="submit" class="btn btn-primary" value={trans("Save")} />
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"session" => params}, socket = %{assigns: %{}}) do
    changeset =
      socket.assigns.changeset
      |> Changeset.cast(params, [:metadata, :index_page_size])
      |> Changeset.update_change(:metadata, &parse_map_param/1)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", params, socket) do
    session =
      socket.assigns.changeset
      |> Changeset.cast(params["session"] || %{}, [:metadata, :locale, :index_page_size])
      |> Changeset.update_change(:metadata, &parse_map_param/1)
      |> Changeset.apply_action!(:insert)

    LiveAdmin.session_store().persist!(session)

    LiveAdmin.announce(trans("Session updated"), :success, session)

    {:noreply, assign(socket, :changeset, Changeset.change(session))}
  end

  defp parse_map_param(param = %{}) do
    param
    |> Enum.sort_by(fn {idx, _} -> idx end)
    |> Map.new(fn {_, %{"key" => key, "value" => value}} -> {key, value} end)
  end
end
