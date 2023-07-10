defmodule LiveAdmin.Components.Container.Index do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin,
    only: [
      associated_resource: 3,
      record_label: 2,
      route_with_params: 2,
      trans: 1,
      trans: 2
    ]

  alias LiveAdmin.Resource
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
            Map.take(assigns, [:prefix, :sort_attr, :sort_dir, :page, :search]),
            assigns.session,
            assigns.repo
          )
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
              placeholder={"#{trans("Search")}..."}
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
                  trans(humanize(field)),
                  assigns,
                  [
                    sort_attr: field,
                    sort_dir:
                      if(field == @sort_attr,
                        do: Enum.find([:asc, :desc], &(&1 != @sort_dir)),
                        else: @sort_dir
                      )
                  ],
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
                        xmlns="http://www.w3.org/2000/svg"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke-width="1.5"
                        stroke="currentColor"
                        width="24"
                        height="24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M6.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0zM12.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0zM18.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0z"
                        />
                      </svg>
                    </a>
                    <nav>
                      <ul>
                        <li>
                          <%= live_redirect(trans("Edit"),
                            to: route_with_params(assigns, segments: [:edit, record])
                          ) %>
                        </li>
                        <%= if @resource.__live_admin_config__(:delete_with) != false do %>
                          <li>
                            <%= link(trans("Delete"),
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
                        <%= for action <- (@resource.__live_admin_config__(:actions) || []) do %>
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
            <td class="w-full" colspan={@resource |> Resource.fields() |> Enum.count()}>
              <%= if @page > 1,
                do:
                  list_link(
                    trans("Prev"),
                    assigns,
                    [page: @page - 1],
                    class: "resource__action--btn"
                  ),
                else: content_tag(:span, trans("Prev"), class: "resource__action--disabled") %>
              <%= if @page < (@records |> elem(1)) / 10,
                do:
                  list_link(
                    trans("Next"),
                    assigns,
                    [page: @page + 1],
                    class: "resource__action--btn"
                  ),
                else: content_tag(:span, trans("Next"), class: "resource__action--disabled") %>
            </td>
            <td class="text-right p-2">
              <%= trans("%{count} total rows", inter: [count: elem(@records, 1)]) %>
            </td>
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
            session: session
          }
        } = socket
      ) do
    socket =
      id
      |> Resource.find!(resource, socket.assigns.prefix, socket.assigns.repo)
      |> Resource.delete(resource, session, socket.assigns.repo)
      |> case do
        {:ok, record} ->
          socket
          |> push_event("success", %{
            msg: trans("Deleted %{label}", inter: [label: record_label(record, resource)])
          })
          |> assign(
            :records,
            Resource.list(
              resource,
              Map.take(socket.assigns, [:prefix, :sort_attr, :sort_dir, :page, :search]),
              session,
              socket.assigns.repo
            )
          )

        {:error, _} ->
          push_event(socket, "error", %{
            msg: trans("Delete failed!")
          })
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "action",
        %{"action" => action, "id" => id},
        socket = %{assigns: %{resource: resource}}
      ) do
    record =
      Resource.find!(
        id,
        resource.__live_admin_config__(:schema),
        socket.assigns.prefix,
        socket.assigns.repo
      )

    action_name = String.to_existing_atom(action)

    {m, f, a} =
      :actions
      |> resource.__live_admin_config__()
      |> Enum.find_value(fn
        {^action_name, mfa} -> mfa
        ^action_name -> {resource, action_name, []}
        _ -> false
      end)

    socket =
      case apply(m, f, [record, socket.assigns.session] ++ a) do
        {:ok, result} ->
          socket
          |> push_event("success", %{
            msg:
              trans(
                "Successfully completed %{action}: %{result}",
                inter: [action: action, result: inspect(result)]
              )
          })
          |> assign(
            :records,
            Resource.list(
              resource,
              Map.take(socket.assigns, [:prefix, :sort_attr, :sort_dir, :page, :search]),
              socket.assigns.session,
              socket.assigns.repo
            )
          )

        {:error, error} ->
          push_event(
            socket,
            "error",
            trans("%{action} failed: %{error}",
              inter: [
                action: action,
                error: error
              ]
            )
          )
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket = %{assigns: assigns}) do
    {:noreply,
     push_patch(socket,
       to:
         route_with_params(socket.assigns,
           params:
             assigns
             |> Map.take([:prefix, :sort_dir, :sort_attr, :page])
             |> Map.put(:search, query)
         )
     )}
  end

  def cell_contents(record, field, record, assigns) do
    schema = assigns.resource.__live_admin_config__(:schema)

    if associated_resource(schema, field, assigns.resources) do
      record_label(
        Map.fetch!(record, get_assoc_name!(schema, field)),
        associated_resource(schema, field, assigns.resources)
      )
    else
      :render_with
      |> assigns.resource.__live_admin_config__()
      |> case do
        {m, f, a} ->
          apply(m, f, [record, field, assigns.session] ++ a)

        f when is_atom(f) ->
          apply(assigns.resource, f, [
            record,
            field,
            assigns.session
          ])
      end
    end
  end

  defp list_link(content, assigns, params, opts) do
    new_params =
      assigns
      |> Map.take([:search, :page, :sort_attr, :sort_dir, :prefix])
      |> Enum.into([])
      |> Keyword.merge(params)

    live_patch(
      content,
      Keyword.put(
        opts,
        :to,
        route_with_params(assigns, params: new_params)
      )
    )
  end

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
