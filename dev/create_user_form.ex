defmodule DemoWeb.CreateUserForm do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import Phoenix.HTML.Form

  import LiveAdmin, only: [route_with_params: 2]
  import LiveAdmin.ErrorHelpers

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:changeset, Ecto.Changeset.change(%Demo.Accounts.User{}))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :enabled, Enum.empty?(assigns.changeset.errors))

    ~H"""
    <div>
      <div class="content-header">
        <h1 class="content-title">
          User <span>Create</span>
        </h1>
      </div>

      <div class="content-card">
        <div class="card-section">
          <div class="edit-view">
            <.form
              :let={f}
              for={@changeset}
              as={:params}
              phx-change="validate"
              phx-submit="create"
              phx-target={@myself}
            >
              <div class="form-grid">
                <div class={"form-field #{if f.errors[:name], do: "error"}"}>
                  <div class="form-label">{label(f, :name)}</div>
                  {textarea(f, :name, rows: 1, class: "form-textarea")}
                  <span class="error-message">{error_tag(f, :name)}</span>
                </div>

                <div class={"form-field #{if f.errors[:email], do: "error"}"}>
                  <div class="form-label">{label(f, :email)}</div>
                  {textarea(f, :email, rows: 1, class: "form-textarea")}
                  <span class="error-message">{error_tag(f, :email)}</span>
                </div>

                <div class={"form-field #{if f.errors[:password], do: "error"}"}>
                  <div class="form-label">{label(f, :password)}</div>
                  {password_input(f, :password, class: "form-input", value: input_value(f, :password))}
                  <span class="error-message">{error_tag(f, :password)}</span>
                </div>

                <div class={"form-field #{if f.errors[:password_confirmation], do: "error"}"}>
                  <div class="form-label">{label(f, :password_confirmation)}</div>
                  {password_input(f, :password_confirmation, class: "form-input")}
                  <span class="error-message">{error_tag(f, :password_confirmation)}</span>
                </div>
              </div>

              <div class="form-actions">
                {submit("Save", class: "btn btn-primary", disabled: !@enabled)}
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "validate",
        %{"params" => params},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    changeset =
      changeset.data
      |> Ecto.Changeset.cast(params, [:name, :email, :password])
      |> Ecto.Changeset.validate_required([:name, :email, :password])
      |> Ecto.Changeset.validate_confirmation(:password)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("create", %{"params" => params}, socket = %{assigns: assigns}) do
    socket =
      %Demo.Accounts.User{}
      |> Ecto.Changeset.cast(params, [:name, :email, :stars_count, :roles])
      |> Ecto.Changeset.validate_required([:name, :email])
      |> Ecto.Changeset.unique_constraint(:email)
      |> Demo.Repo.insert(prefix: assigns.prefix)
      |> case do
        {:ok, _} ->
          push_navigate(socket, to: route_with_params(assigns, params: [prefix: assigns.prefix]))

        {:error, changeset} ->
          assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end
end
