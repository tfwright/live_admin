defmodule Phoenix.LiveAdmin.Components.Resource do
  use Phoenix.LiveView
  use Phoenix.HTML

  import Phoenix.LiveAdmin.ErrorHelpers

  alias Ecto.Changeset

  @impl true
  def mount(params, _session, socket) do
    {:ok, assign(socket, :resource, String.to_existing_atom(params["resource"]))}
  end

  @impl true
  def handle_params(unsigned_params, uri, socket) do
    IO.inspect(unsigned_params, label: "params changed!")
    IO.inspect(unsigned_params, label: "socket")
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "validate",
        %{"params" => params},
        %{assigns: %{resource: resource}} = socket
      ) do
    record = Map.get(socket.assigns, :record, struct(resource, %{}))

    changeset =
      record
      |> change_resource(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset, record: record)}
  end

  @impl true
  def handle_event(
        "save",
        %{"params" => params},
        %{assigns: %{resource: resource, record: record}} = socket
      ) do
      record
      |> change_resource(params)
      |> repo().insert!()

    {:noreply,
     redirect(socket, to: socket.router.__helpers__().resource_path(socket, :list, resource))}
  end

  def render("new.html", assigns = %{resource: resource}) do
    assigns = Map.put_new(assigns, :changeset, change_resource(struct(resource, %{})))

    ~L"""
    <%= form_for @changeset, "#", [as: "params", phx_change: "validate", phx_submit: "save", class: "w-3/4 shadow-md p-2"], fn f -> %>
      <%= for field <- fields(resource) do %>
        <div class="flex flex-col mb-4">
          <%= label f, field, class: "mb-2 uppercase font-bold text-lg text-grey-darkest" %>
          <%= text_input f, field, class: "border py-2 px-3 text-grey-darkest"  %>
          <%= error_tag f, field %>
        </div>
      <% end %>
      <div class="text-right">
        <%= submit "Save", class: "inline-flex items-center h-8 px-4 m-2 text-sm text-indigo-100 transition-colors duration-150 bg-indigo-700 rounded-lg focus:shadow-outline hover:bg-indigo-800" %>
      </div>
    <% end %>
    """
  end

  def render("list.html", assigns) do
    ~L"""
    <table class="w-full shadow-md rounded table-auto border-collapse border-1">
      <thead>
        <tr>
          <%= for field <- fields(@resource) do %>
            <th class="bg-blue-100 border text-left px-8 py-4"><%= field %></th>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <%= for record <- repo().all(@resource) do %>
          <tr>
            <%= for field <- fields(@resource) do %>
              <td class="border px-8 py-4"><%= Map.fetch!(record, field) %></td>
            <% end %>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp fields(resource), do: resource.__schema__(:fields)

  defp change_resource(record = %resource{}, params \\ %{}),
    do: Changeset.cast(record, params, fields(resource))

  defp repo, do: Application.fetch_env!(:phoenix_live_admin, :ecto_repo)
end
