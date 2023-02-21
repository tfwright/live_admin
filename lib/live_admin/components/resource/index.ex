defmodule LiveAdmin.Components.Container.Index do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin,
    only: [
      repo: 0,
      associated_resource: 3,
      record_label: 2,
      get_config: 3
    ]

  import LiveAdmin.Components.Container, only: [route_with_params: 3]

  alias LiveAdmin.{Resource, SessionStore}
  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(
        records:
          Resource.list(
            assigns.resource,
            Map.take(assigns, [:prefix, :sort, :page, :search]),
            SessionStore.lookup(assigns.session_id)
          ),
        sort_attr: elem(assigns.sort, 1),
        sort_dir: elem(assigns.sort, 0)
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="resource__list">
      <div class="list__search">
        <div class="flex border-2 rounded-lg">
          <form phx-change={JS.push("search", target: @myself, page_loading: true)}>
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
            <th class="resource__header" />
            <%= for {field, _, _} <- Resource.fields(@resource) do %>
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
          </tr>
        </thead>
        <tbody id="index-page" phx-hook="IndexPage">
          <%= for record <- @records |> elem(0) do %>
            <tr>
              <td>
                <div class="cell__contents">
                  <div class="resource__menu--drop">
                    <a href="#">
                      <svg
                        viewBox="0 0 24 24"
                        version="1.1"
                        xmlns="http://www.w3.org/2000/svg"
                        xmlns:xlink="http://www.w3.org/1999/xlink"
                        fill="#000000"
                      >
                        <g stroke-width="0"></g>
                        <g stroke-linecap="round" stroke-linejoin="round"></g>
                        <g>
                          <g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
                            <rect x="0" y="0" width="24" height="24"></rect>

                            <path
                              d="M5,14 C6.1045695,14 7,13.1045695 7,12 C7,10.8954305 6.1045695,10 5,10 C3.8954305,10 3,10.8954305 3,12 C3,13.1045695 3.8954305,14 5,14 Z"
                              fill="#030819"
                            >
                            </path>

                            <path
                              d="M12,14 C13.1045695,14 14,13.1045695 14,12 C14,10.8954305 13.1045695,10 12,10 C10.8954305,10 10,10.8954305 10,12 C10,13.1045695 10.8954305,14 12,14 Z"
                              fill="#030819"
                            >
                            </path>

                            <path
                              d="M19,14 C20.1045695,14 21,13.1045695 21,12 C21,10.8954305 20.1045695,10 19,10 C17.8954305,10 17,10.8954305 17,12 C17,13.1045695 17.8954305,14 19,14 Z"
                              fill="#030819"
                            >
                            </path>
                          </g>
                        </g>
                      </svg>
                    </a>
                    <nav>
                      <ul>
                        <li>
                          <%= live_redirect("Edit",
                            to: route_with_params(@socket, [:edit, @key, record], prefix: @prefix)
                          ) %>
                        </li>
                        <%= if get_config(@resource.config, :delete_with, true) do %>
                          <li>
                            <%= link("Delete",
                              to: "#",
                              "data-confirm": "Are you sure?",
                              "phx-click":
                                JS.push("delete",
                                  value: %{id: record.id},
                                  target: @myself,
                                  page_loading: true
                                )
                            ) %>
                          </li>
                        <% end %>
                        <%= for action <- Map.get(@resource.config, :actions, []) do %>
                          <li>
                            <%= link(action |> to_string() |> humanize(),
                              to: "#",
                              "data-confirm": "Are you sure?",
                              "phx-click":
                                JS.push("action",
                                  value: %{id: record.id, action: action},
                                  target: @myself,
                                  page_loading: true
                                )
                            ) %>
                          </li>
                        <% end %>
                      </ul>
                    </nav>
                  </div>
                </div>
              </td>
              <%= for {field, type, _} <- Resource.fields(@resource) do %>
                <td class={"resource__cell resource__cell--#{type_to_css_class(type)}"}>
                  <div class="cell__contents">
                    <%= cell_contents(record, field, record, assigns) %>
                  </div>
                  <div class="cell__copy" data-message="Copied cell contents to clipboard">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M 4 2 C 2.895 2 2 2.895 2 4 L 2 18 L 4 18 L 4 4 L 18 4 L 18 2 L 4 2 z M 8 6 C 6.895 6 6 6.895 6 8 L 6 20 C 6 21.105 6.895 22 8 22 L 20 22 C 21.105 22 22 21.105 22 20 L 22 8 C 22 6.895 21.105 6 20 6 L 8 6 z M 8 8 L 20 8 L 20 20 L 8 20 L 8 8 z" />
                    </svg>
                  </div>
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
        <tfoot>
          <tr>
            <td class="w-full" colspan={@resource |> Resource.fields() |> Enum.count() |> Kernel.-(1)}>
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
            session_id: session_id
          }
        } = socket
      ) do
    socket =
      id
      |> Resource.find!(resource, socket.assigns.prefix)
      |> Resource.delete(resource.config, SessionStore.lookup(session_id))
      |> case do
        {:ok, _} ->
          socket
          |> push_event("success", %{msg: "Deleted #{resource.schema}"})
          |> assign(
            :records,
            Resource.list(
              resource,
              Map.take(socket.assigns, [:prefix, :sort, :page, :search]),
              SessionStore.lookup(session_id)
            )
          )

        {:error, _} ->
          push_event(socket, "error", %{msg: "Could not delete #{resource.schema}"})
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("action", %{"action" => action, "id" => id}, socket) do
    record = Resource.find!(id, socket.assigns.resource, socket.assigns.prefix)

    action_name = String.to_existing_atom(action)

    session = SessionStore.lookup(socket.assigns.session_id)

    {m, f, a} =
      socket.assigns.resource.config
      |> get_config(:actions, [])
      |> Enum.find_value(fn
        {^action_name, mfa} -> mfa
        ^action_name -> {socket.assigns.resource.schema, action_name, []}
        _ -> false
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

  defp associated_record(record = %schema{}, field_name) do
    with assoc_name when not is_nil(assoc_name) <- get_assoc_name!(schema, field_name),
         %{^assoc_name => assoc_record} <- repo().preload(record, assoc_name) do
      assoc_record
    else
      _ -> nil
    end
  end

  def cell_contents(record, field, record, assigns) do
    if associated_resource(assigns.resource.schema, field, assigns.resources) do
      record_label(
        associated_record(record, field),
        associated_resource(assigns.resource.schema, field, assigns.resources)
      )
    else
      session = SessionStore.lookup(assigns.session_id)

      assigns.resource.config
      |> get_config(:render_with, {LiveAdmin.View, :render_field, []})
      |> case do
        {m, f, a} -> apply(m, f, [record, field, session] ++ a)
        f when is_atom(f) -> apply(assigns.resource.schema, f, [record, field, session])
      end
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

  defp type_to_css_class({_, type, _}), do: type_to_css_class(type)
  defp type_to_css_class({:array, {_, type, _}}), do: {:array, type} |> type_to_css_class()
  defp type_to_css_class({:array, type}), do: "array.#{type}" |> type_to_css_class()

  defp type_to_css_class(type),
    do: type |> to_string() |> Phoenix.Naming.underscore() |> String.replace("/", "_")
end
