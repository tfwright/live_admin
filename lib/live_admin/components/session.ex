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
end
