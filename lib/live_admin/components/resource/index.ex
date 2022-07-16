defmodule LiveAdmin.Components.Container.Index do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin,
    only: [repo: 0, associated_resource: 3, record_label: 2, get_config: 3]

  import LiveAdmin.Components.Container, only: [route_with_params: 3]

  alias LiveAdmin.{Resource, SessionStore}

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        records:
          Resource.list(
            assigns.resource,
            assigns.config,
            Map.take(assigns, [:prefix, :sort, :page, :search]),
            SessionStore.lookup(assigns.session_id)
          ),
        sort_attr: elem(assigns.sort, 1),
        sort_dir: elem(assigns.sort, 0)
      )

    ~H"""
    <div class="resource__list">
      <div class="list__search">
        <div class="flex border-2 rounded-lg">
          <form phx-change="search" phx-target={@myself}>
            <input
              type="text"
              placeholder="Search..."
              name="query"
              onkeydown="return event.key != 'Enter'"
              value={@search}
              phx-debounce="500"
            />
          </form>
          <button
            phx-click="search"
            phx-value-query=""
            phx-target={@myself}
            class="flex items-center justify-center px-2 border-l"
          >
            <svg fill="currentColor" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
              <path d="M16.32 14.9l5.39 5.4a1 1 0 0 1-1.42 1.4l-5.38-5.38a8 8 0 1 1 1.41-1.41zM10 16a6 6 0 1 0 0-12 6 6 0 0 0 0 12z" />
            </svg>
          </button>
        </div>
      </div>
      <table class="resource__table">
        <thead>
          <tr>
            <%= for {field, _, _} <- Resource.fields(@resource, @config) do %>
              <th class="resource__header" title={field}>
                <%= list_link(
                  @socket,
                  humanize(field),
                  @key,
                  %{
                    prefix: @prefix,
                    page: @page,
                    "sort-attr": field,
                    "sort-dir":
                      if(field == @sort_attr,
                        do: Enum.find([:asc, :desc], &(&1 != @sort_dir)),
                        else: @sort_dir
                      ),
                    s: @search
                  },
                  class:
                    "header__link#{if field == @sort_attr, do: "--#{[asc: :up, desc: :down][@sort_dir]}"}"
                ) %>
              </th>
            <% end %>
            <th class="resource__header">Actions</th>
          </tr>
        </thead>
        <tbody id="index-page" phx-hook="IndexPage">
          <%= for record <- @records |> elem(0) do %>
            <tr>
              <%= for {field, type, _} <- Resource.fields(@resource, @config) do %>
                <td class={"resource__cell--#{type_to_css_class(type)}"}>
                  <div class="cell__contents">
                    <%= display_field(record, field, assigns) %>
                  </div>
                  <%= if Map.fetch!(record, field) do %>
                    <div
                      class="cell__copy"
                      data-clipboard-text={record |> Map.fetch!(field) |> print()}
                    >
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M 4 2 C 2.895 2 2 2.895 2 4 L 2 18 L 4 18 L 4 4 L 18 4 L 18 2 L 4 2 z M 8 6 C 6.895 6 6 6.895 6 8 L 6 20 C 6 21.105 6.895 22 8 22 L 20 22 C 21.105 22 22 21.105 22 20 L 22 8 C 22 6.895 21.105 6 20 6 L 8 6 z M 8 8 L 20 8 L 20 20 L 8 20 L 8 8 z" />
                      </svg>
                    </div>
                  <% end %>
                </td>
              <% end %>
              <td class="resource__cell--actions">
                <%= live_redirect("Edit",
                  to: route_with_params(@socket, [:edit, @key, record], prefix: @prefix),
                  class: "resource__action--btn"
                ) %>
                <%= if get_config(@config, :delete_with, true) do %>
                  <%= link("Delete",
                    to: "#",
                    "data-confirm": "Are you sure?",
                    "phx-click": "delete",
                    "phx-value-id": record.id,
                    "phx-target": @myself,
                    class: "resource__action--btn"
                  ) %>
                <% end %>
                <%= for action <- Map.get(@config, :actions, []) do %>
                  <%= link(action |> to_string() |> humanize(),
                    to: "#",
                    "data-confirm": "Are you sure?",
                    "phx-click": "action",
                    "phx-value-id": record.id,
                    "phx-value-action": action,
                    "phx-target": @myself,
                    class: "resource__action--btn"
                  ) %>
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
        <tfoot>
          <tr>
            <td class="w-full" colspan={@resource |> Resource.fields(@config) |> Enum.count()}>
              <%= if @page > 1,
                do:
                  list_link(
                    @socket,
                    "Prev",
                    @key,
                    %{
                      prefix: @prefix,
                      page: @page - 1,
                      "sort-attr": @sort_attr,
                      "sort-dir": @sort_dir,
                      s: @search
                    },
                    class: "resource__action--btn"
                  ),
                else: content_tag(:span, "Prev", class: "resource__action--disabled") %>
              <%= if @page < (@records |> elem(1)) / 10,
                do:
                  list_link(
                    @socket,
                    "Next",
                    @key,
                    %{
                      prefix: @prefix,
                      page: @page + 1,
                      "sort-attr": @sort_attr,
                      "sort-dir": @sort_dir,
                      s: @search
                    },
                    class: "resource__action--btn"
                  ),
                else: content_tag(:span, "Next", class: "resource__action--disabled") %>
            </td>
            <td class="text-right p-2"><%= @records |> elem(1) %> total rows</td>
          </tr>
        </tfoot>
      </table>
    </div>
    """
  end

  @impl true
  def handle_event(
        "delete",
        %{"id" => id},
        %{
          assigns: %{
            resource: resource,
            config: config,
            session_id: session_id
          }
        } = socket
      ) do
    socket =
      id
      |> Resource.find!(resource, socket.assigns.prefix)
      |> Resource.delete(config, SessionStore.lookup(session_id))
      |> case do
        {:ok, _} ->
          socket
          |> push_event("success", %{msg: "Deleted #{resource}"})
          |> assign(
            :records,
            Resource.list(
              resource,
              config,
              Map.take(socket.assigns, [:prefix, :sort, :page, :search]),
              SessionStore.lookup(session_id)
            )
          )

        {:error, _} ->
          push_event(socket, "error", %{msg: "Could not delete #{resource}"})
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("action", %{"action" => action, "id" => id}, socket) do
    record = Resource.find!(id, socket.assigns.resource, socket.assigns.prefix)

    action_name = String.to_existing_atom(action)

    session = SessionStore.lookup(socket.assigns.session_id)

    {m, f, a} =
      socket.assigns.config
      |> get_config(:actions, [])
      |> Enum.find_value(fn
        {^action_name, mfa} -> mfa
        ^action_name -> {socket.assigns.resource, action_name, []}
      end)

    socket =
      case apply(m, f, [record, session] ++ a) do
        {:ok, result} ->
          socket
          |> push_event("success", %{
            msg: "Successfully completed #{action}: #{inspect(result)}"
          })
          |> assign(
            :records,
            Resource.list(
              socket.assigns.resource,
              socket.assigns.config,
              Map.take(socket.assigns, [:prefix, :sort, :page, :search]),
              SessionStore.lookup(socket.assigns.session_id)
            )
          )

        {:error, error} ->
          push_event(socket, "error", %{msg: "#{action} failed: #{error}"})
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

  defp display_field(record = %schema{}, field_name, assigns) do
    with {key, {_, config}} <-
           associated_resource(schema, field_name, assigns.resources),
         assoc_name <- get_assoc_name!(schema, field_name),
         %{^assoc_name => assoc_record} when not is_nil(assoc_record) <-
           repo().preload(record, assoc_name) do
      assoc_record
      |> record_label(config)
      |> live_redirect(
        to: route_with_params(assigns.socket, [:edit, key, assoc_record], prefix: assigns.prefix),
        class: "resource__action--btn"
      )
    else
      _ -> record |> Map.fetch!(field_name) |> print()
    end
  end

  defp list_link(socket, content, key, params, opts),
    do:
      live_patch(content, Keyword.put(opts, :to, route_with_params(socket, [:list, key], params)))

  defp get_assoc_name!(schema, fk) do
    Enum.find(schema.__schema__(:associations), fn assoc_name ->
      fk == schema.__schema__(:association, assoc_name).owner_key
    end)
  end

  defp print(term) when is_binary(term), do: term
  defp print(term), do: inspect(term)

  defp type_to_css_class({_, type, _}), do: type_to_css_class(type)
  defp type_to_css_class({:array, {_, type, _}}), do: {:array, type} |> type_to_css_class()
  defp type_to_css_class({:array, type}), do: "array.#{type}" |> type_to_css_class()

  defp type_to_css_class(type),
    do: type |> to_string() |> Phoenix.Naming.underscore() |> String.replace("/", "_")
end
