defmodule LiveAdmin.Components.Session do
  use Phoenix.LiveView

  alias __MODULE__.Content
  alias Ecto.Changeset

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
    assigns =
      assign(assigns, mod: Application.get_env(:live_admin, :components, [])[:session] || Content)

    ~H"""
    <.live_component module={@mod} id="content" changeset={@changeset} />
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
