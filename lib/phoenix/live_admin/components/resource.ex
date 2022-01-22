defmodule Phoenix.LiveAdmin.Components.Resource do
  use Phoenix.LiveView
  use Phoenix.HTML

  import Ecto.Query

  alias Ecto.Changeset
  alias __MODULE__.{Form, Index}

  @impl true
  def mount(%{"resource_id" => key}, _session, socket) do
    {resource, config} = Map.fetch!(socket.assigns.resources, key)

    socket =
      assign(socket,
        resource: resource,
        key: key,
        config: config,
        metadata: %{},
        loading: !connected?(socket)
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket = %{assigns: %{loading: false}}) do
    socket =
      socket
      |> assign_prefix(params)
      |> assign_params(params)
      |> case do
        socket = %{assigns: %{live_action: :new}} ->
          assign(socket, :changeset, changeset(socket.assigns.resource, socket.assigns.config))

        socket = %{assigns: %{live_action: :edit}} ->
          changeset =
            params
            |> Map.fetch!("record_id")
            |> get_resource!(socket.assigns.resource, socket.assigns.metadata[:__prefix__])
            |> changeset(socket.assigns.config)

          assign(socket, changeset: changeset)

        socket = %{assigns: %{live_action: :list}} ->
          page = String.to_integer(params["page"] || "1")

          assign(socket,
            records: list(socket.assigns.resource, page, socket.assigns.metadata[:__prefix__]),
            page: page,
            params: Map.put(socket.assigns.params, "page", page)
          )

        socket ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

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
          |> push_redirect(to: route_with_params(socket, [:list, key], socket.assigns[:params]))

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
          |> push_redirect(to: route_with_params(socket, [:list, key], socket.assigns[:params]))

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
      |> get_resource!(resource, socket.assigns.metadata[:__prefix__])
      |> delete_resource(config, metadata)
      |> case do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Deleted #{resource}")
          |> push_redirect(to: route_with_params(socket, [:list, key], socket.assigns[:params]))

        {:error, _} ->
          put_flash(socket, :error, "Could not delete #{resource}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "search",
        %{"query" => q},
        %{assigns: %{resource: resource, page: page}} = socket
      ) do
    records = list(resource, page, socket.assigns.metadata[:__prefix__], search: q)

    socket = assign(socket, :records, records)

    {:noreply, socket}
  end

  def render(assigns = %{loading: true}), do: ~H""

  @impl true
  def render(assigns) do
    ~H"""
    <div class="resource__banner">
      <h1 class="resource__title">
        <%= @resource |> Module.split() |> Enum.join(".") %>
      </h1>

      <div class="resource__actions">
        <div>
          <%= live_redirect "List", to: route_with_params(@socket, [:list, @key], assigns[:params]), class: "resource__action--btn" %>
          <%= live_redirect "New", to: route_with_params(@socket, [:new, @key], Map.delete(assigns[:params], "page")), class: "resource__action--btn" %>
          <%= if Application.get_env(:phoenix_live_admin, :prefix_options) do %>
            <div class="resource__action--drop">
              <button>Prefix: <%= assigns.metadata[:__prefix__] || "none" %></button>
              <nav>
                <ul>
                  <%= if assigns.metadata[:__prefix__] do %>
                    <li>
                      <%= live_patch("clear", to: @socket.router.__helpers__().resource_path(@socket, :list, @key)) %>
                    </li>
                  <% end %>
                  <%= for option <- get_prefix_options!(), to_string(option) != assigns.metadata[:__prefix__] do %>
                    <li>
                    <%= live_patch(option, to: @socket.router.__helpers__().resource_path(@socket, :list, @key, prefix: option)) %>
                    </li>
                  <% end %>
                </ul>
              </nav>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <div class="flash">
      <p class="resource__error"><%= live_flash(@flash, :error) %></p>
      <p class="resource__info"><%= live_flash(@flash, :info) %></p>
    </div>

    <%= render "#{@live_action}.html", assigns %>
    """
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
    ~H"""
    <Index.render socket={@socket} resources={@resources} resource={@resource} config={@config} key={@key} page={@page} records={@records} params={assigns[:params]} />
    """
  end

  def repo, do: Application.fetch_env!(:phoenix_live_admin, :ecto_repo)

  def fields(resource, config) do
    Enum.flat_map(resource.__schema__(:fields), fn field_name ->
      config
      |> Map.get(:hidden_fields, [])
      |> Enum.member?(field_name)
      |> case do
        false ->
          [
            {field_name, resource.__schema__(:type, field_name),
             [immutable: Map.get(config, :immutable_fields, []) |> Enum.member?(field_name)]}
          ]

        true ->
          []
      end
    end)
  end

  def list(resource, page, prefix, opts \\ []) do
    query =
      resource
      |> limit(10)
      |> offset(^((page - 1) * 10))

    query =
      opts
      |> Enum.reduce(query, fn
        {:search, q}, query -> apply_search(query, q, fields(resource, %{}))
      end)

    repo().all(query, prefix: prefix)

    {
      repo().all(query, prefix: prefix),
      repo().aggregate(query |> exclude(:limit) |> exclude(:offset), :count, prefix: prefix)
    }
  end

  def route_with_params(socket, segments, params) do
    apply(socket.router.__helpers__(), :resource_path, [socket] ++ segments ++ [params || %{}])
  end

  def get_resource!(id, resource, prefix), do: repo().get!(resource, id, prefix: prefix)

  def get_prefix_options!() do
    Application.fetch_env!(:phoenix_live_admin, :prefix_options)
    |> case do
      {mod, func, args} -> apply(mod, func, args)
      list when is_list(list) -> list
    end
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
      {field, {_, Ecto.Embedded, %{related: embed_schema}}, _}, changeset ->
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
        {field, type, opts} when is_atom(type) ->
          if Keyword.get(opts, :immutable, false), do: [], else: [field]

        _ ->
          []
      end)

    Changeset.cast(record, params, field_names)
  end

  defp create_resource(resource, config, params, metadata) do
    config
    |> Map.get(:create_with)
    |> case do
      nil ->
        resource
        |> changeset(config, params)
        |> repo().insert(prefix: metadata[:__prefix__])

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

  defp apply_search(query, q, fields) do
    Enum.reduce(fields, query, fn {field_name, _, _}, query ->
      or_where(query, [r], ilike(fragment("CAST(? AS text)", field(r, ^field_name)), ^"%#{q}%"))
    end)
  end

  defp assign_prefix(socket, %{"prefix" => prefix}),
    do: assign(socket, :metadata, Map.put(socket.assigns.metadata, :__prefix__, prefix))

  defp assign_prefix(socket, _),
    do: assign(socket, :metadata, Map.put(socket.assigns.metadata, :__prefix__, nil))

  defp assign_params(socket, params) do
    assign(socket, :params, Map.take(params, ["prefix"]))
  end
end
