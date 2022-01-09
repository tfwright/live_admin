defmodule Phoenix.LiveAdmin.Components.Resource do
  use Phoenix.LiveView
  use Phoenix.HTML

  alias Ecto.Changeset
  alias __MODULE__.{Form}

  @castable_types [:string, :integer, :boolean, :utc_datetime, :date]

  @impl true
  def mount(%{"resource" => key}, _session, socket) do
    resource = Map.fetch!(socket.assigns.resources, key)
    socket = assign(socket, resource: resource, key: key)

    socket = if socket.assigns.live_action == :new do
      assign(socket, :changeset, changeset(resource))
    else
      socket
    end

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "validate",
        %{"params" => params},
        %{assigns: %{resource: resource}} = socket
      ) do
    changeset =
      resource
      |> changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event(
        "save",
        %{"params" => params},
        %{assigns: %{resource: resource, key: key}} = socket
      ) do
      resource
      |> changeset(params)
      |> repo().insert!()

    {:noreply,
     redirect(socket, to: socket.router.__helpers__().resource_path(socket, :list, key))}
  end

  def render("new.html", assigns) do
    ~H"""
    <Form.render changeset={@changeset} />
    """
  end

  def render("list.html", assigns) do
    ~L"""
    <table class="w-full shadow-md rounded table-auto border-collapse border-1">
      <thead>
        <tr>
          <%= for {field, _} <- fields(@resource) do %>
            <th class="bg-blue-100 border text-left px-8 py-4"><%= field %></th>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <%= for record <- repo().all(@resource) do %>
          <tr>
            <%= for {field, _} <- fields(@resource) do %>
              <td class="border px-8 py-4">
                <%= record |> Map.fetch!(field) |> inspect() %>
              </td>
            <% end %>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  def fields(resource), do: resource.__schema__(:fields) |> Enum.map(& {&1, resource.__schema__(:type, &1)})

  defp changeset(resource, params \\ %{}) do
    resource
    |> struct(%{})
    |> change_resource(params)
  end

  defp change_resource(record = %resource{}, params) do
    fields = fields(resource)

    changeset = cast_fields(record, params, fields)

    Enum.reduce(fields, changeset, fn
      {field, {_, Ecto.Embedded, %{related: embed_schema}}}, changeset ->
        embed_fields = fields(embed_schema)

        Changeset.cast_embed(changeset, field, with: fn embed, params ->
          cast_fields(embed, params, embed_fields)
        end)
      _, changeset -> changeset
    end)
  end

  defp cast_fields(record, params, fields) do
    castable_fields = Enum.flat_map(fields, fn
        {field, type} when type in @castable_types -> [field]
        _ -> []
    end)

    Changeset.cast(record, params, castable_fields)
  end

  defp repo, do: Application.fetch_env!(:phoenix_live_admin, :ecto_repo)
end
