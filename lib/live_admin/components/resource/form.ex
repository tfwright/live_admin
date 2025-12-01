defmodule LiveAdmin.Components.Container.Form do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import LiveAdmin.Components
  import LiveAdmin

  alias Ecto.Changeset
  alias LiveAdmin.Resource

  @impl true
  def update(assigns = %{record: record}, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:enabled, false)
      |> assign(:changeset, Resource.change(assigns.resource, record, assigns.config))

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:changeset, Resource.change(assigns.resource, assigns.config))

    {:ok, socket}
  end

  @impl true
  def render(assigns = %{record: nil}) do
    ~H"""
    <div>{trans("No record found")}</div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div phx-hook="Form" id="form-page">
      <div class="content-header">
        <h1 class="content-title">
          {resource_title(@resource, @config)}
          <%= if assigns[:record] do %>
            <span>{record_label(@record, @resource, @config)}</span>
          <% else %>
            <span>{trans("Create")}</span>
          <% end %>
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
              phx-submit={@action}
              phx-target={@myself}
            >
              <.form_grid
                form={f}
                resource={@resource}
                resources={@resources}
                session={@session}
                prefix={@prefix}
                repo={@repo}
                config={@config}
                fields={Resource.fields(@resource, @config)}
                target={@myself}
              />

              <div class="form-actions">
                <.link
                  class="btn btn-danger"
                  data-confirm="Are you sure?"
                  navigate={
                    if assigns[:record],
                      do: route_with_params(assigns, segments: [@record]),
                      else: route_with_params(assigns)
                  }
                >
                  {trans("Cancel")}
                </.link>
                <input
                  type="submit"
                  class="btn btn-primary"
                  value={trans("Save")}
                  disabled={Enum.any?(@changeset.errors)}
                />
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
        socket = %{
          assigns: %{resource: resource, changeset: changeset, session: session, config: config}
        }
      ) do
    changeset = validate(resource, changeset, params, session, config)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event(
        "create",
        %{"params" => params},
        %{assigns: %{resource: resource, session: session, repo: repo, config: config}} = socket
      ) do
    socket =
      case Resource.create(resource, params, session, repo, config) do
        {:ok, _} ->
          LiveAdmin.PubSub.announce(
            session.id,
            :success,
            trans("Record added")
          )

          push_navigate(socket,
            to: route_with_params(socket.assigns, params: [prefix: socket.assigns.prefix])
          )

        {:error, changeset} ->
          assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "update",
        %{"params" => params},
        %{assigns: %{resource: resource, session: session, record: record, config: config}} =
          socket
      ) do
    socket =
      Resource.update(record, resource, params, session, config)
      |> case do
        {:ok, _} ->
          LiveAdmin.PubSub.announce(
            session.id,
            :success,
            trans("Changes saved")
          )

          push_navigate(socket, to: route_with_params(socket.assigns, segments: [record]))

        {:error, changeset} ->
          assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end

  def handle_event("add_embed", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)

    changeset =
      socket.assigns.changeset
      |> Changeset.get_change(field)
      |> case do
        nil ->
          Changeset.put_change(socket.assigns.changeset, field, %{})

        val when is_list(val) ->
          Changeset.update_change(
            socket.assigns.changeset,
            field,
            &List.insert_at(&1, -1, %{})
          )
      end

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("remove_embed", params = %{"field" => field}, socket) do
    field = String.to_existing_atom(field)

    changeset =
      socket.assigns.changeset
      |> Changeset.get_change(field)
      |> case do
        val when is_list(val) ->
          Changeset.update_change(
            socket.assigns.changeset,
            field,
            &List.delete_at(&1, params |> Map.fetch!("index") |> String.to_integer())
          )

        _ ->
          Changeset.put_change(socket.assigns.changeset, field, nil)
      end

    {:noreply, assign(socket, :changeset, changeset)}
  end

  defp validate(resource, changeset, params, session, config) do
    resource
    |> Resource.change(changeset.data, params, config)
    |> Resource.validate(resource, session, config)
  end
end
