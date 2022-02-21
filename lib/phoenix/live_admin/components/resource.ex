defmodule Phoenix.LiveAdmin.Components.Resource do
  use Phoenix.LiveView
  use Phoenix.HTML

  import Ecto.Query
  import Phoenix.LiveAdmin, only: [resource_title: 3, parent_associations: 1, get_config: 2, get_config: 3]

  alias Ecto.Changeset
  alias __MODULE__.{Form, Index}
  alias Phoenix.LiveAdmin.SessionStore

  @impl true
  def mount(%{"resource_id" => key}, %{"id" => session_id}, socket) do
    {resource, config} = Map.fetch!(socket.assigns.resources, key)

    SessionStore.get_or_init(session_id)

    socket =
      assign(socket,
        resource: resource,
        key: key,
        config: config,
        session_id: session_id
      )
      |> assign_prefix()
      |> case do
        socket = %{assigns: %{live_action: action}} when action in [:list, :edit] ->
          assign(socket, :loading, !connected?(socket))

        socket = %{assigns: %{live_action: :new}} ->
          assign(socket, :changeset, changeset(socket.assigns.resource, socket.assigns.config))

        socket ->
          socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket = %{assigns: %{live_action: :edit, loading: false}}) do
    socket = assign_prefix(socket, params["prefix"])

    changeset =
      params
      |> Map.fetch!("record_id")
      |> get_resource!(socket.assigns.resource, socket.assigns.prefix)
      |> changeset(socket.assigns.config)

    socket = assign(socket, changeset: changeset)

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, _uri, socket = %{assigns: %{live_action: :list, loading: false}}) do
    page = String.to_integer(params["page"] || "1")

    sort = {
      String.to_existing_atom(params["sort-dir"] || "asc"),
      String.to_existing_atom(params["sort-attr"] || "id")
    }

    socket =
      socket
      |> assign(page: page)
      |> assign(sort: sort)
      |> assign(search: params["s"])
      |> reload_list()

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_prefix", params, socket) do
    SessionStore.set(socket.assigns.session_id, :__prefix__, params["prefix"])

    socket =
      socket
      |> assign_prefix()
      |> push_redirect(
        to: route_with_params(socket, [:list, socket.assigns.key], prefix: params["prefix"])
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "validate",
        %{"params" => params},
        %{assigns: %{changeset: changeset, config: config, session_id: session_id}} = socket
      ) do
    changeset =
      changeset.data
      |> changeset(config, params)
      |> validate_resource(config, SessionStore.lookup(session_id))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event(
        "create",
        %{"params" => params},
        %{assigns: %{resource: resource, key: key, config: config, session_id: session_id}} =
          socket
      ) do
    socket =
      case create_resource(resource, config, params, SessionStore.lookup(session_id)) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Created #{resource}")
          |> push_redirect(to: route_with_params(socket, [:list, key]))

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
            session_id: session_id,
            changeset: changeset
          }
        } = socket
      ) do
    socket =
      case update_resource(
             changeset.data,
             config,
             params,
             SessionStore.lookup(session_id)
           ) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Updated #{resource}")
          |> push_redirect(to: route_with_params(socket, [:list, key]))

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
            session_id: session_id,
            page: page
          }
        } = socket
      ) do
    socket =
      id
      |> get_resource!(resource, socket.assigns.prefix)
      |> delete_resource(config, SessionStore.lookup(session_id))
      |> case do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Deleted #{resource}")
          |> push_redirect(to: route_with_params(socket, [:list, key], page: page))

        {:error, _} ->
          put_flash(socket, :error, "Could not delete #{resource}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("action", %{"action" => action, "id" => id}, socket) do
    record = socket.assigns.records |> elem(0) |> Enum.find(&(to_string(&1.id) == id))

    action_name = String.to_existing_atom(action)

    session = SessionStore.lookup(socket.assigns.session_id)

    {m, f, a} =
      socket.assigns
      |> get_in([:config, :actions, action_name])
      |> case do
        nil -> {socket.assigns.resource, action_name, []}
        tuple when tuple_size(tuple) == 3 -> tuple
      end

    socket =
      case apply(m, f, [record, session] ++ a) do
        {:ok, result} ->
          socket
          |> put_flash(:info, "Successfully completed #{action}: #{inspect(result)}")
          |> push_redirect(
            to:
              route_with_params(
                socket,
                [:list, socket.assigns.key],
                Map.take(socket.assigns, [:prefix, :page])
              )
          )

        {:error, error} ->
          put_flash(socket, :error, "#{action} failed: #{error}")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    params = %{
      page: socket.assigns.page,
      "sort-attr": elem(socket.assigns.sort, 1),
      "sort-dir": elem(socket.assigns.sort, 0),
      s: query,
      prefix: socket.assigns.prefix
    }

    socket =
      push_patch(socket, to: route_with_params(socket, [:list, socket.assigns.key], params))

    {:noreply, socket}
  end

  def render(assigns = %{loading: true}), do: ~H""

  @impl true
  def render(assigns) do
    ~H"""
    <div class="resource__banner">
      <h1 class="resource__title">
        <%= resource_title(@resource, @config, @base_path) %>
      </h1>

      <div class="resource__actions">
        <div>
          <%= live_redirect "List", to: route_with_params(@socket, [:list, @key], prefix: @prefix), class: "resource__action--btn" %>
          <%= live_redirect "New", to: route_with_params(@socket, [:new, @key]), class: "resource__action--btn" %>
          <%= if Application.get_env(:phoenix_live_admin, :prefix_options) do %>
            <div class="resource__action--drop">
              <button><%= @prefix || "Set prefix" %></button>
              <nav>
                <ul>
                  <%= if @prefix do %>
                    <li>
                      <a href="#" phx-click="set_prefix">clear</a>
                    </li>
                  <% end %>
                  <%= for option <- get_prefix_options!(), to_string(option) != @prefix do %>
                    <li>
                      <a href="#" phx-click="set_prefix" phx-value-prefix={option}><%= option %></a>
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
    assigns = assign(assigns, :action, "create")

    {mod, func, args} = get_in(assigns, [:config, :components, :new]) || {Form, :render, []}

    apply(mod, func, [assigns] ++ args)
  end

  def render("edit.html", assigns) do
    assigns = assign(assigns, :action, "update")

    {mod, func, args} = get_in(assigns, [:config, :components, :edit]) || {Form, :render, []}

    apply(mod, func, [assigns] ++ args)
  end

  def render("list.html", assigns) do
    ~H"""
    <Index.render
      socket={@socket}
      resources={@resources}
      resource={@resource}
      config={@config}
      key={@key}
      page={@page}
      records={@records}
      sort_attr={elem(@sort, 1)}
      sort_dir={elem(@sort, 0)}
      search={@search}
      prefix={@prefix}
    />
    """
  end

  def repo, do: Application.fetch_env!(:phoenix_live_admin, :ecto_repo)

  def fields(resource, config) do
    Enum.flat_map(resource.__schema__(:fields), fn field_name ->
      config
      |> get_config(:hidden_fields, [])
      |> Enum.member?(field_name)
      |> case do
        false ->
          [
            {field_name, resource.__schema__(:type, field_name),
             [immutable: get_config(config, :immutable_fields, []) |> Enum.member?(field_name)]}
          ]

        true ->
          []
      end
    end)
  end

  def list(resource, config, opts \\ []) do
    opts =
      opts
      |> Enum.into(%{})
      |> Map.put_new(:page, 1)
      |> Map.put_new(:sort, {:asc, :id})

    query =
      resource
      |> limit(10)
      |> offset(^((opts[:page] - 1) * 10))
      |> order_by(^[opts[:sort]])
      |> preload(^preloads_for_resource(resource, config))

    query =
      opts
      |> Enum.reduce(query, fn
        {:search, q}, query when byte_size(q) > 0 ->
          apply_search(query, q, fields(resource, config))

        _, query ->
          query
      end)

    {
      repo().all(query, prefix: opts[:prefix]),
      repo().aggregate(query |> exclude(:limit) |> exclude(:offset), :count, prefix: opts[:prefix])
    }
  end

  def route_with_params(socket, segments, params \\ %{}) do
    params =
      Enum.flat_map(params, fn
        {:prefix, nil} -> []
        pair -> [pair]
      end)

    apply(socket.router.__helpers__(), :resource_path, [socket] ++ segments ++ [params])
  end

  def get_resource!(id, resource, prefix), do: repo().get!(resource, id, prefix: prefix)

  def get_prefix_options!() do
    Application.fetch_env!(:phoenix_live_admin, :prefix_options)
    |> case do
      {mod, func, args} -> apply(mod, func, args)
      list when is_list(list) -> list
    end
    |> Enum.sort()
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

    {primitives, embeds} =
      Enum.split_with(fields, fn
        {_, {_, Ecto.Embedded, _}, _} -> false
        _ -> true
      end)

    castable_fields =
      Enum.flat_map(primitives, fn {field, _, opts} ->
        if Keyword.get(opts, :immutable, false), do: [], else: [field]
      end)

    changeset = Changeset.cast(record, params, castable_fields)

    Enum.reduce(embeds, changeset, fn {field, {_, Ecto.Embedded, _}, _}, changeset ->
      Changeset.cast_embed(changeset, field,
        with: fn embed, params ->
          change_resource(embed, %{}, params)
        end
      )
    end)
  end

  defp create_resource(resource, config, params, session) do
    config
    |> get_config(:create_with)
    |> case do
      nil ->
        resource
        |> changeset(config, params)
        |> repo().insert(prefix: session[:__prefix__])

      {mod, func_name, args} ->
        apply(mod, func_name, [params, session] ++ args)
    end
  end

  defp update_resource(record, config, params, session) do
    config
    |> get_config(:update_with)
    |> case do
      nil ->
        record
        |> changeset(config, params)
        |> repo().update()

      {mod, func_name, args} ->
        apply(mod, func_name, [params, session] ++ args)
    end
  end

  defp delete_resource(record, config, session) do
    config
    |> get_config(:delete_with)
    |> case do
      nil ->
        repo().delete(record)

      {mod, func_name, args} ->
        apply(mod, func_name, [record, session] ++ args)
    end
  end

  defp validate_resource(changeset, config, session) do
    config
    |> get_config(:validate_with)
    |> case do
      nil -> changeset
      {mod, func_name, args} -> apply(mod, func_name, [changeset, session] ++ args)
    end
  end

  defp apply_search(query, q, fields) do
    q
    |> IO.inspect()
    |> String.split(~r{[^\s]*:}, include_captures: true, trim: true)
    |> case do
      [q] ->
        Enum.reduce(fields, query, fn {field_name, _, _}, query ->
          or_where(
            query,
            [r],
            ilike(fragment("CAST(? AS text)", field(r, ^field_name)), ^"%#{q}%")
          )
        end)

      field_queries ->
        field_queries
        |> Enum.map(&String.trim/1)
        |> Enum.chunk_every(2)
        |> Enum.reduce(query, fn
          [field_key, q], query ->
            if {field_name, _, _} =
                 Enum.find(fields, fn {field_name, _, _} -> "#{field_name}:" == field_key end) do
              or_where(
                query,
                [r],
                ilike(fragment("CAST(? AS text)", field(r, ^field_name)), ^"%#{q}%")
              )
            else
              query
            end

          [_], query ->
            query
        end)
    end
  end

  def assign_prefix(_, prefix \\ nil)

  def assign_prefix(socket, nil),
    do: assign(socket, :prefix, SessionStore.lookup(socket.assigns.session_id, :__prefix__))

  def assign_prefix(socket, prefix) do
    SessionStore.set(socket.assigns.session_id, :__prefix__, prefix)

    assign(socket, :prefix, prefix)
  end

  defp reload_list(socket),
    do:
      assign(socket,
        records:
          list(
            socket.assigns.resource,
            socket.assigns.config,
            Map.take(socket.assigns, [:prefix, :sort, :page, :search])
          )
      )

  defp preloads_for_resource(resource, config) do
    config
    |> Map.get(:preload)
    |> case do
      nil -> resource |> parent_associations() |> Enum.map(& &1.field)
      {m, f, a} -> apply(m, f, [resource | a])
      preloads when is_list(preloads) -> preloads
    end
  end
end
