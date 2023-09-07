defmodule LiveAdmin.Components.Container.Index do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin,
    only: [
      route_with_params: 1,
      route_with_params: 2,
      trans: 1,
      trans: 2
    ]

  import LiveAdmin.Components

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
    <div id="index-page" phx-hook="IndexPage" phx-target={@myself}>
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
            <th class="resource__header">
              <input
                type="checkbox"
                id="select-all"
                class="resource__select"
                phx-click={JS.dispatch("live_admin:toggle_select")}
              />
            </th>
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
        <tbody>
          <%= for record <- @records |> elem(0) do %>
            <tr class="resource__row">
              <td>
                <div class="cell__contents">
                  <input
                    type="checkbox"
                    class="resource__select"
                    data-record-id={record.id}
                    phx-click={JS.dispatch("live_admin:toggle_select")}
                  />
                </div>
              </td>
              <%= for {field, type, _} <- Resource.fields(@resource) do %>
                <% assoc_resource =
                  LiveAdmin.associated_resource(
                    @resource.__live_admin_config__(:schema),
                    field,
                    @resources
                  ) %>
                <td class={"resource__cell resource__cell--#{type_to_css_class(type)}"}>
                  <div class="cell__contents">
                    <%= Resource.render(record, field, @resource, assoc_resource, @session) %>
                  </div>
                  <div class="cell__icons">
                    <div class="cell__copy" data-message="Copied cell contents to clipboard">
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M 4 2 C 2.895 2 2 2.895 2 4 L 2 18 L 4 18 L 4 4 L 18 4 L 18 2 L 4 2 z M 8 6 C 6.895 6 6 6.895 6 8 L 6 20 C 6 21.105 6.895 22 8 22 L 20 22 C 21.105 22 22 21.105 22 20 L 22 8 C 22 6.895 21.105 6 20 6 L 8 6 z M 8 8 L 20 8 L 20 20 L 8 20 L 8 8 z" />
                      </svg>
                    </div>
                    <%= if record |> Ecto.primary_key() |> Keyword.keys() |> Enum.member?(field) || (assoc_resource && Map.fetch!(record, field)) do %>
                      <a
                        class="cell__link"
                        href={
                          if assoc_resource,
                            do:
                              route_with_params(assigns,
                                resource_path: elem(assoc_resource, 0),
                                segments: [Map.fetch!(record, field)]
                              ),
                            else: route_with_params(assigns, segments: [record])
                        }
                        target="_blank"
                      >
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke-width="1.5"
                          stroke="currentColor"
                          class="w-6 h-6"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"
                          />
                        </svg>
                      </a>
                    <% end %>
                  </div>
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
        <tfoot>
          <tr id="footer-nav">
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
          <tr id="footer-select" class="hidden">
            <td colspan={@resource |> Resource.fields() |> Enum.count()}>
              <div class="table__actions">
                <%= if @resource.__live_admin_config__(:delete_with) != false do %>
                  <button
                    class="resource__action--danger"
                    data-action="delete"
                    phx-click={JS.dispatch("live_admin:action")}
                    data-confirm="Are you sure?"
                  >
                    <%= trans("Delete") %>
                  </button>
                <% end %>
                <.dropdown
                  :let={action}
                  orientation={:up}
                  label={trans("Run action")}
                  items={@resource.__live_admin_config__(:actions)}
                  disabled={Enum.empty?(@resource.__live_admin_config__(:actions))}
                >
                  <button
                    class="resource__action--link"
                    data-action={action}
                    phx-click={JS.dispatch("live_admin:action")}
                    data-confirm="Are you sure?"
                  >
                    <%= action |> to_string() |> humanize() %>
                  </button>
                </.dropdown>
              </div>
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
    """
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

  @impl true
  def handle_event(
        "delete",
        %{"ids" => ids},
        %{
          assigns: %{
            resource: resource,
            session: session,
            prefix: prefix,
            repo: repo
          }
        } = socket
      ) do
    results =
      ids
      |> Resource.all(resource, prefix, repo)
      |> Enum.map(fn record ->
        Task.Supervisor.async(LiveAdmin.Task.Supervisor, fn ->
          Resource.delete(record, resource, session, socket.assigns.repo)
        end)
      end)
      |> Task.await_many()

    socket =
      socket
      |> put_flash(
        :info,
        trans("Deleted %{count} records", inter: [count: Enum.count(results)])
      )
      |> push_navigate(to: route_with_params(socket.assigns))

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "action",
        %{"action" => action, "ids" => ids},
        socket = %{assigns: %{resource: resource, prefix: prefix, repo: repo}}
      ) do
    records = Resource.all(ids, resource, prefix, repo)

    action_name = String.to_existing_atom(action)

    results =
      records
      |> Enum.map(fn record ->
        Task.Supervisor.async(LiveAdmin.Task.Supervisor, fn ->
          {m, f, a} =
            :actions
            |> resource.__live_admin_config__()
            |> Enum.find_value(fn
              {^action_name, mfa} -> mfa
              ^action_name -> {resource, action_name, []}
              _ -> false
            end)

          apply(m, f, [record, socket.assigns.session] ++ a)
        end)
      end)
      |> Task.await_many()

    socket =
      socket
      |> put_flash(
        :info,
        trans("Action completed on %{count} records: %{action}",
          inter: [count: Enum.count(results), action: action]
        )
      )
      |> push_navigate(to: route_with_params(socket.assigns))

    {:noreply, socket}
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

  defp type_to_css_class({_, type, _}), do: type_to_css_class(type)
  defp type_to_css_class({:array, {_, type, _}}), do: {:array, type} |> type_to_css_class()
  defp type_to_css_class({:array, type}), do: "array.#{type}" |> type_to_css_class()

  defp type_to_css_class(type),
    do: type |> to_string() |> Phoenix.Naming.underscore() |> String.replace("/", "_")
end
