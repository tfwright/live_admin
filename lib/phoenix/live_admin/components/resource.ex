defmodule Phoenix.LiveAdmin.Components.Resource do
  use Phoenix.LiveView
  use Phoenix.HTML

  alias Ecto.Changeset
  alias __MODULE__.{Form}

  @impl true
  def mount(%{"resource_id" => key}, _session, socket) do
    {resource, config} = Map.fetch!(socket.assigns.resources, key)
    socket = assign(socket, resource: resource, key: key, config: config, metadata: %{})

    socket =
      if socket.assigns.live_action == :new do
        assign(socket, :changeset, changeset(resource, config))
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "validate",
        %{"params" => params},
        %{assigns: %{resource: resource, config: config, metadata: metadata}} = socket
      ) do
    changeset =
      resource
      |> changeset(config, params)
      |> validate_resource(config, metadata)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event(
        "save",
        %{"params" => params},
        %{assigns: %{resource: resource, key: key, config: config, metadata: metadata}} = socket
      ) do
    socket =
      case create_resource(resource, config, params, metadata) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Created #{resource}")
          |> push_redirect(to: socket.router.__helpers__().resource_path(socket, :list, key))

        {:error, _} ->
          put_flash(socket, :error, "Could not create #{resource}")
      end

    {:noreply, socket}
  end

  def render("new.html", assigns) do
    ~H"""
    <Form.render resource={@resource} config={@config} changeset={@changeset} />
    """
  end

  def render("list.html", assigns) do
    ~L"""
    <table class="w-full shadow-md rounded table-auto border-collapse border-1">
      <thead>
        <tr>
          <%= for {field, _} <- fields(@resource, @config) do %>
            <th class="bg-blue-100 border text-left px-8 py-4"><%= field %></th>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <%= for record <- repo().all(@resource) do %>
          <tr>
            <%= for {field, _} <- fields(@resource, @config) do %>
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

  def fields(resource, config) do
    Enum.flat_map(resource.__schema__(:fields), fn field_name ->
      config
      |> Map.get(:hidden_fields, [])
      |> Enum.member?(field_name)
      |> case do
        false -> [{field_name, resource.__schema__(:type, field_name)}]
        true -> []
      end
    end)
  end

  defp changeset(resource, config, params \\ %{}) do
    resource
    |> struct(%{})
    |> change_resource(config, params)
  end

  defp change_resource(record = %resource{}, config, params) do
    fields = fields(resource, config)

    changeset = cast_fields(record, params, fields)

    Enum.reduce(fields, changeset, fn
      {field, {_, Ecto.Embedded, %{related: embed_schema}}}, changeset ->
        embed_fields = fields(embed_schema, config)

        Changeset.cast_embed(changeset, field,
          with: fn embed, params ->
            cast_fields(embed, params, embed_fields)
          end
        )

      _, changeset ->
        changeset
    end)
  end

  defp cast_fields(record, params, fields) do
    field_names =
      Enum.flat_map(fields, fn
        {field, type} when is_atom(type) -> [field]
        _ -> []
      end)

    Changeset.cast(record, params, field_names)
  end

  defp repo, do: Application.fetch_env!(:phoenix_live_admin, :ecto_repo)

  defp create_resource(resource, config, params, metadata) do
    config
    |> Map.get(:create_with)
    |> case do
      nil ->
        resource
        |> changeset(config, params)
        |> repo().insert()

      {mod, func_name, args} ->
        apply(mod, func_name, [params, metadata] ++ args)
    end
  end

  defp validate_resource(changeset, config, metadata) do
    config
    |> Map.get(:validate_with)
    |> case do
      nil -> changeset
      {mod, func_name, args} -> apply(mod, func_name, [changeset, metadata] ++ args)
    end
  end
end
