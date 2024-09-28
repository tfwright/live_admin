defmodule LiveAdmin.Components.Container.Index do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import LiveAdmin,
    only: [
      route_with_params: 1,
      route_with_params: 2,
      trans: 1,
      trans: 2
    ]

  import LiveAdmin.Components
  import LiveAdmin.View, only: [get_function_keys: 3]

  alias LiveAdmin.Resource
  alias Phoenix.LiveView.JS

  @impl true
  def update(
        %{changed: keys},
        socket = %{assigns: %{resource: resource, prefix: prefix, repo: repo}}
      ) do
    socket =
      update(socket, :records, fn result ->
        {records, count} = result.result

        records =
          Enum.flat_map(records, fn record ->
            record_key = Map.fetch!(record, LiveAdmin.primary_key!(resource))

            if Enum.member?(keys, record_key) do
              record = LiveAdmin.Resource.find(record_key, resource, prefix, repo)

              if record, do: [record], else: []
            else
              [record]
            end
          end)

        Map.put(result, :result, {records, count})
      end)

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_async(
        [:records],
        fn ->
          {:ok,
           %{
             records:
               Resource.list(
                 assigns.resource,
                 list_link_params(assigns),
                 assigns.session,
                 assigns.repo,
                 assigns.config
               )
           }}
        end,
        reset: true
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="view__container" phx-hook="IndexPage" phx-target={@myself}>
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
      <div class="table__wrapper">
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
              <%= for {field, _, _} <- Resource.fields(@resource, @config) do %>
                <th class="resource__header" title={field}>
                  <.link
                    patch={
                      route_with_params(
                        assigns,
                        params:
                          list_link_params(assigns,
                            sort_attr: field,
                            sort_dir:
                              if(field == @sort_attr,
                                do: Enum.find([:asc, :desc], &(&1 != @sort_dir)),
                                else: @sort_dir
                              )
                          )
                      )
                    }
                    class={"header__link#{if field == @sort_attr, do: "--#{[asc: :up, desc: :down][@sort_dir]}"}"}
                  >
                    <%= trans(humanize(field)) %>
                  </.link>
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= if @records.ok? do %>
              <%= for record <- @records.result |> elem(0) do %>
                <tr class="resource__row">
                  <td>
                    <div class="cell__contents">
                      <input
                        type="checkbox"
                        class="resource__select"
                        data-record-key={Map.fetch!(record, LiveAdmin.primary_key!(@resource))}
                        phx-click={JS.dispatch("live_admin:toggle_select")}
                      />
                    </div>
                  </td>
                  <%= for {field, type, _} <- Resource.fields(@resource, @config) do %>
                    <% assoc_resource =
                      LiveAdmin.associated_resource(
                        LiveAdmin.fetch_config(@resource, :schema, @config),
                        field,
                        @resources
                      ) %>
                    <td class={"resource__cell resource__cell--#{type_to_css_class(type)}"}>
                      <div class="cell__contents">
                        <%= Resource.render(
                          record,
                          field,
                          @resource,
                          assoc_resource,
                          @session,
                          @config
                        ) %>
                      </div>
                      <div class="cell__icons">
                        <div class="cell__copy" data-message="Copied cell contents to clipboard">
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            viewBox="0 0 24 24"
                            fill="currentColor"
                          >
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
            <% else %>
              <tr>
                <td class="p-10">
                  <%= if @records.loading do %>
                    <div class="spinner" />
                  <% else %>
                    <%= trans("Error") %>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      <div class="table__footer">
        <div id="footer-nav">
          <%= if @records.ok? do %>
            <div>
              <%= if @page > 1 do %>
                <.link patch={
                  route_with_params(
                    assigns,
                    params: list_link_params(assigns, page: @page - 1)
                  )
                }>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="currentColor"
                    class="size-6"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M7.72 12.53a.75.75 0 0 1 0-1.06l7.5-7.5a.75.75 0 1 1 1.06 1.06L9.31 12l6.97 6.97a.75.75 0 1 1-1.06 1.06l-7.5-7.5Z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </.link>
              <% end %>

              <button
                class="resource__action--secondary"
                phx-click={
                  JS.show(
                    to: "#pagination-modal",
                    transition: {"ease-in duration-300", "opacity-0", "opacity-100"}
                  )
                }
              >
                <%= min((@page - 1) * @per + 1, elem(@records.result, 1)) %>-<%= min(
                  @page * @per,
                  elem(@records.result, 1)
                ) %>/<%= elem(@records.result, 1) %>
              </button>

              <%= if @page < (@records.result |> elem(1)) / 10 do %>
                <.link patch={
                  route_with_params(
                    assigns,
                    params: list_link_params(assigns, page: @page + 1)
                  )
                }>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="currentColor"
                    class="size-6"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M16.28 11.47a.75.75 0 0 1 0 1.06l-7.5 7.5a.75.75 0 0 1-1.06-1.06L14.69 12 7.72 5.03a.75.75 0 0 1 1.06-1.06l7.5 7.5Z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>
        <div id="footer-select" style="display:none">
          <div>
            <%= if !assigns[:job] do %>
              <div class="table__actions">
                <%= if LiveAdmin.fetch_config(@resource, :delete_with, @config) != false do %>
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
                  items={get_function_keys(@resource, @config, :actions)}
                  disabled={Enum.empty?(LiveAdmin.fetch_config(@resource, :actions, @config))}
                >
                  <.action_control action={action} session={@session} resource={@resource} />
                </.dropdown>
              </div>
            <% else %>
              <div>
                <%= elem(@job, 0) %>: <%= elem(@job, 1) %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
      <.modal id="pagination-modal">
        <div class="modal__title"><%= trans("Page") %></div>
        <form phx-submit="go" phx-target={@myself}>
          <div>
            <label><%= trans("Number") %></label>
            <input type="number" name="page" value={@page} />
          </div>
          <div>
            <label><%= trans("Size") %></label>
            <input type="number" name="per" value={@per} />
          </div>
          <input type="submit" value="Go" phx-click={JS.hide(to: "#pagination-modal")} />
        </form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event(
        "task",
        params = %{"name" => task},
        socket = %{
          assigns: %{search: search, session: session, resource: resource, config: config}
        }
      ) do
    {_, m, f, _, _} =
      LiveAdmin.fetch_function(resource, session, :tasks, String.to_existing_atom(task))

    args = [session | Map.get(params, "args", [])]

    Task.Supervisor.async_nolink(LiveAdmin.Task.Supervisor, m, f, [
      Resource.query(resource, search, config) | args
    ])

    socket =
      socket
      |> put_flash(:info, trans("%{task} started", inter: [task: task]))
      |> push_navigate(to: route_with_params(socket.assigns))

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket = %{assigns: assigns}) do
    {:noreply,
     push_patch(socket,
       to:
         route_with_params(socket.assigns,
           params: list_link_params(assigns, search: query)
         )
     )}
  end

  @impl true
  def handle_event("go", %{"page" => page, "per" => per}, socket = %{assigns: assigns}) do
    {:noreply,
     push_patch(socket,
       to:
         route_with_params(socket.assigns,
           params: list_link_params(assigns, page: page, per: per)
         )
     )}
  end

  @impl true
  def handle_event(
        "action",
        params = %{"name" => action, "ids" => ids},
        socket = %{
          assigns: %{
            session: session,
            resource: resource,
            prefix: prefix,
            repo: repo,
            config: config
          }
        }
      ) do
    {label, mod, func, args} =
      if action == "delete" do
        {"delete", Resource, :delete, [resource, session, repo, config]}
      else
        {label, mod, func, _, _} =
          LiveAdmin.fetch_function(
            resource,
            session,
            :actions,
            String.to_existing_atom(action)
          )

        {label, mod, func, [session | Map.get(params, "args", [])]}
      end

    Task.Supervisor.async_nolink(
      LiveAdmin.Task.Supervisor,
      fn ->
        pid = self()

        Phoenix.PubSub.broadcast(
          LiveAdmin.PubSub,
          "session:#{session.id}",
          {:job, pid, :start, label}
        )

        records = Resource.all(ids, resource, prefix, repo)

        Enum.reduce(records, 0.0, fn record, progress ->
          apply(mod, func, [record | args])

          progress = progress + 1 / length(records)

          Phoenix.PubSub.broadcast(
            LiveAdmin.PubSub,
            "session:#{session.id}",
            {:job, pid, :progress, progress}
          )

          progress
        end)

        Phoenix.PubSub.broadcast(
          LiveAdmin.PubSub,
          "session:#{session.id}",
          {:job, pid, :complete}
        )
      end,
      timeout: :infinity
    )

    socket =
      socket
      |> put_flash(
        :info,
        trans("Action running on %{count} records: %{action}",
          inter: [count: Enum.count(ids), action: action]
        )
      )
      |> push_redirect(
        to: route_with_params(socket.assigns, params: list_link_params(socket.assigns))
      )

    {:noreply, socket}
  end

  defp list_link_params(assigns, overrides \\ []) do
    assigns
    |> Map.take([:search, :page, :sort_attr, :sort_dir, :prefix, :per])
    |> Enum.into([])
    |> Keyword.merge(overrides)
  end

  defp type_to_css_class({_, {type, _}}), do: type_to_css_class(type)
  defp type_to_css_class({:array, {_, {type, _}}}), do: {:array, type} |> type_to_css_class()
  defp type_to_css_class({:array, type}), do: "array.#{type}" |> type_to_css_class()

  defp type_to_css_class(type),
    do: type |> to_string() |> Phoenix.Naming.underscore() |> String.replace("/", "_")
end
