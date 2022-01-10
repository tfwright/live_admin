defmodule Phoenix.LiveAdmin.Components.Resource do
  use Phoenix.LiveView
  use Phoenix.HTML

  alias Ecto.Changeset
  alias __MODULE__.{Form}

  @impl true
  def mount(params = %{"resource_id" => key}, _session, socket) do
    {resource, config} = Map.fetch!(socket.assigns.resources, key)
    socket = assign(socket, resource: resource, key: key, config: config, metadata: %{})

    socket =
      case socket.assigns.live_action do
        :new ->
          assign(socket, :changeset, changeset(resource, config))

        :edit ->
          changeset =
            params
            |> Map.fetch!("record_id")
            |> get_resource!(resource)
            |> changeset(config)

          assign(socket, changeset: changeset)

        _ ->
          socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "validate",
        %{"params" => params},
        %{assigns: %{changeset: changeset, config: config, metadata: metadata}} = socket
      ) do
    changeset =
      changeset.data
      |> changeset(config, params)
      |> validate_resource(config, metadata)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event(
        "create",
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

  @impl true
  def handle_event(
        "update",
        %{"params" => params},
        %{
          assigns: %{
            resource: resource,
            key: key,
            config: config,
            metadata: metadata,
            changeset: changeset
          }
        } = socket
      ) do
    socket =
      case update_resource(changeset.data, config, params, metadata) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Updated #{resource}")
          |> push_redirect(to: socket.router.__helpers__().resource_path(socket, :list, key))

        {:error, _} ->
          put_flash(socket, :error, "Could not update #{resource}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "delete",
        %{"id" => id},
        %{
          assigns: %{
            resource: resource,
            key: key,
            config: config,
            metadata: metadata
          }
        } = socket
      ) do
    socket =
      id
      |> get_resource!(resource)
      |> delete_resource(config, metadata)
      |> case do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Deleted #{resource}")
          |> push_redirect(to: socket.router.__helpers__().resource_path(socket, :list, key))

        {:error, _} ->
          put_flash(socket, :error, "Could not delete #{resource}")
      end

    {:noreply, socket}
  end

  def render("new.html", assigns) do
    ~H"""
    <Form.render resource={@resource} config={@config} changeset={@changeset} action="create" />
    """
  end

  def render("edit.html", assigns) do
    ~H"""
    <Form.render resource={@resource} config={@config} changeset={@changeset} action="update" />
    """
  end

  def render("list.html", assigns) do
    ~L"""
    <div class="resource__list">
      <table class="resource__table">
        <thead>
          <tr>
            <%= for {field, _} <- fields(@resource, @config) do %>
              <th class="resource__header"><%= field %></th>
            <% end %>
            <th class="resource__header">Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= for record <- repo().all(@resource) do %>
            <tr>
              <%= for {field, _} <- fields(@resource, @config) do %>
                <td class="resource__cell">
                  <%= record |> Map.fetch!(field) |> inspect() %>
                </td>
              <% end %>
              <td class="resource__cell">
                <%= live_redirect "Edit", to: @socket.router.__helpers__().resource_path(@socket, :edit, @key, record.id), class: "inline-flex items-center h-8 px-4 m-2 text-sm text-indigo-100 transition-colors duration-150 bg-indigo-700 rounded-lg focus:shadow-outline hover:bg-indigo-800" %>
                <%= link "Delete", to: "#", "data-confirm": "Are you sure?", "phx-click": "delete", "phx-value-id": record.id, class: "inline-flex items-center h-8 px-4 m-2 text-sm text-indigo-100 transition-colors duration-150 bg-indigo-700 rounded-lg focus:shadow-outline hover:bg-indigo-800" %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
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

  defp changeset(record, config, params \\ %{})

  defp changeset(record, config, params) when is_struct(record) do
    change_resource(record, config, params)
  end

  defp changeset(resource, config, params) do
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

  defp update_resource(record, config, params, metadata) do
    config
    |> Map.get(:update_with)
    |> case do
      nil ->
        record
        |> changeset(config, params)
        |> repo().update()

      {mod, func_name, args} ->
        apply(mod, func_name, [params, metadata] ++ args)
    end
  end

  defp delete_resource(record, config, metadata) do
    config
    |> Map.get(:delete_with)
    |> case do
      nil ->
        repo().delete(record)

      {mod, func_name, args} ->
        apply(mod, func_name, [record, metadata] ++ args)
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

  def get_resource!(id, resource), do: repo().get!(resource, id)
end
