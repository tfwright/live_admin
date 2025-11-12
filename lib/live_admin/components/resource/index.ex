defmodule LiveAdmin.Components.Container.Index do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import LiveAdmin
  import LiveAdmin.Components
  import LiveAdmin.View

  require Logger

  alias LiveAdmin.Resource
  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:selected, fn -> [] end)
      |> assign(search: assigns.search || "")
      |> assign_async(
        [:records],
        fn ->
          {records, count} =
            Resource.list(
              assigns.resource,
              index_link_params(assigns),
              assigns.session,
              assigns.repo,
              assigns.config
            )

          {:ok, %{records: {records, count}}}
        end,
        reset: true
      )

    {:ok, socket}
  end

  defp sort_class(field, attr, dir) when field == attr, do: "sort-#{dir}"
  defp sort_class(_, _, _), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div id="index" phx-hook="IndexPage">
      <div class="content-header">
        <h1 class="content-title">
          {resource_title(@resource, @config)}
          <span>{trans("Index")}</span>
        </h1>
        <div class="contextual-actions">
          <.link
            navigate={route_with_params(assigns, segments: ["new"], params: [prefix: @prefix])}
            class="btn btn-primary"
          >
            {trans("Create")}
          </.link>
          <%= if Enum.any?(@selected) do %>
            <%= if LiveAdmin.fetch_config(@resource, :delete_with, @config) != false do %>
              <button
                class="btn btn-danger"
                data-confirm="Are you sure?"
                phx-click={
                  JS.push("action",
                    value: %{name: "delete"},
                    page_loading: true,
                    target: @myself
                  )
                }
              >
                {trans("Delete")}
              </button>
            <% end %>
            <.drop_down
              :let={action}
              id="action-select"
              items={
                @resource
                |> get_function_keys(@config, :actions)
                |> Enum.map(&LiveAdmin.fetch_function(@resource, @session, :actions, &1))
              }
              label={trans("Run action")}
            >
              <.function_control
                name={elem(action, 0)}
                type="action"
                extra_arg_count={elem(action, 3) - 2}
                docs={elem(action, 4)}
                target={@myself}
              />
            </.drop_down>
          <% else %>
            <.drop_down
              :let={task}
              id="task-select"
              items={
                @resource
                |> get_function_keys(@config, :tasks)
                |> Enum.map(&LiveAdmin.fetch_function(@resource, @session, :tasks, &1))
              }
              label={trans("Run task")}
            >
              <.function_control
                name={elem(task, 0)}
                type="task"
                extra_arg_count={elem(task, 3) - 2}
                docs={elem(task, 4)}
                target={@myself}
              />
            </.drop_down>
          <% end %>
        </div>
      </div>

      <div class="content-card">
        <div class="card-section">
          <div>
            <div class="search-container">
              <svg
                class="search-icon"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <circle cx="11" cy="11" r="8" />
                <path d="m21 21-4.35-4.35" />
              </svg>
              <form phx-change={JS.push("search", target: @myself, page_loading: true)}>
                <input
                  type="text"
                  placeholder={"#{trans("Search")}..."}
                  name="query"
                  onkeydown="return event.key != 'Enter'"
                  value={@search}
                  phx-debounce="500"
                  class="search-input"
                />
              </form>
            </div>
            <%= if @records.loading || (@records.ok? && elem(@records.result, 1) > 0) do %>
              <div class="table-container">
                <table class="data-table">
                  <thead>
                    <tr>
                      <th>
                        <form phx-change="toggle_select" phx-debounce={500} phx-target={@myself}>
                          <input
                            type="checkbox"
                            class="row-checkbox"
                            title="Select all"
                            name="all"
                            checked={
                              @records.ok? &&
                                Enum.count(@selected) == Enum.count(elem(@records.result, 0))
                            }
                          />
                        </form>
                      </th>
                      <%= for {field, _, _} <- Resource.fields(@resource, @config) do %>
                        <th class={sort_class(field, @sort_attr, @sort_dir)}>
                          <.link patch={
                            route_with_params(
                              assigns,
                              params:
                                index_link_params(assigns,
                                  sort_attr: field,
                                  sort_dir:
                                    if(field == @sort_attr,
                                      do: Enum.find([:asc, :desc], &(&1 != @sort_dir)),
                                      else: @sort_dir
                                    )
                                )
                            )
                          }>
                            {trans(humanize(field))}
                          </.link>
                        </th>
                      <% end %>
                    </tr>
                  </thead>
                  <tbody>
                    <%= if @records.ok? do %>
                      <%= for record <- elem(@records.result, 0), record_id = Map.fetch!(record, LiveAdmin.primary_key!(@resource)) do %>
                        <tr>
                          <td>
                            <form phx-change="toggle_select" phx-debounce={500} phx-target={@myself}>
                              <input
                                type="checkbox"
                                class="row-checkbox"
                                name="selected"
                                checked={Enum.member?(@selected, record_id)}
                              />
                              <input type="hidden" name="record_id" value={record_id} />
                            </form>
                          </td>
                          <%= for {field, type, _} <- Resource.fields(@resource, @config) do %>
                            <td class="table-cell">
                              <span class="cell-content">
                                {Resource.render(record, field, type, @resource, @config, @session)}
                              </span>
                              <.expand_modal
                                id={"expand-#{record_id}-#{field}"}
                                title={record_label(record, @resource, @config)}
                                value={Map.fetch!(record, field)}
                                field={field}
                              />
                            </td>
                          <% end %>
                        </tr>
                      <% end %>
                    <% end %>
                  </tbody>
                </table>
              </div>
              <%= if @records.ok? do %>
                <div class="pagination">
                  <div class="pagination-controls">
                    <%= if @page > 1 do %>
                      <.link
                        patch={
                          route_with_params(
                            assigns,
                            params: index_link_params(assigns, page: @page - 1)
                          )
                        }
                        class="btn pagination-info-btn"
                      >
                        Back
                      </.link>
                    <% end %>
                    <.link class="btn pagination-info-btn">
                      {min((@page - 1) * @per + 1, elem(@records.result, 1))}-{min(
                        @page * @per,
                        elem(@records.result, 1)
                      )}/{elem(@records.result, 1)}
                    </.link>
                    <%= if @page < (@records.result |> elem(1)) / @per do %>
                      <.link
                        patch={
                          route_with_params(
                            assigns,
                            params: index_link_params(assigns, page: @page + 1)
                          )
                        }
                        class="btn pagination-info-btn"
                      >
                        Next
                      </.link>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% else %>
              <%= if elem(@records.result, 1) == 0 do %>
                <.error title="No results" , details="Check search value and selected prefix" />
              <% else %>
                <.error
                  title="Could not load results"
                  ,
                  details="Try again and if error continues check logs"
                />
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket = %{assigns: assigns}) do
    {:noreply,
     push_patch(socket,
       to:
         route_with_params(socket.assigns,
           params: index_link_params(assigns, search: query)
         )
     )}
  end

  @impl true
  def handle_event(
        "task",
        params = %{"name" => name},
        socket = %{
          assigns: %{session: session, resource: resource, config: config}
        }
      ) do
    {_, m, f, _, _} =
      LiveAdmin.fetch_function(resource, session, :tasks, String.to_existing_atom(name))

    args = [session | Map.get(params, "args", [])]

    job =
      Task.Supervisor.async_nolink(LiveAdmin.Task.Supervisor, fn ->
        try do
          case apply(m, f, [
                 Resource.query(resource, Map.get(socket.assigns, :search), config) | args
               ]) do
            {:ok, message} ->
              LiveAdmin.PubSub.announce(session.id, :success, message)

            {:error, message} ->
              LiveAdmin.PubSub.announce(session.id, :error, message)
          end
        rescue
          error ->
            Logger.error(inspect(error))

            LiveAdmin.PubSub.announce(
              session.id,
              :error,
              trans("Task %{name} failed", inter: [name: name])
            )
        after
          LiveAdmin.PubSub.update_job(session.id, self(), progress: 1)
        end
      end)

    LiveAdmin.PubSub.update_job(session.id, job.pid, progress: 0, label: name)

    {:noreply, push_navigate(socket, to: route_with_params(socket.assigns))}
  end

  @impl true
  def handle_event(
        "action",
        params = %{"name" => name},
        socket = %{
          assigns: %{
            resource: resource,
            session: session,
            prefix: prefix,
            repo: repo,
            config: config
          }
        }
      ) do
    {m, f, a} =
      if name == "delete" do
        {Resource, :delete, [resource, session, repo, config]}
      else
        {_, m, f, _, _} =
          LiveAdmin.fetch_function(resource, session, :actions, String.to_existing_atom(name))

        {m, f, [session | Map.get(params, "args", [])]}
      end

    job =
      Task.Supervisor.async_nolink(LiveAdmin.Task.Supervisor, fn ->
        socket.assigns.selected
        |> Enum.with_index()
        |> Enum.each(fn {id, idx} ->
          try do
            id
            |> Resource.find(resource, prefix, repo)
            |> case do
              nil -> nil
              record -> apply(m, f, [record | a])
            end

            LiveAdmin.PubSub.update_job(session.id, self(),
              progress: idx / Enum.count(socket.assigns.selected),
              label: name
            )
          rescue
            error ->
              Logger.error(inspect(error))

              LiveAdmin.PubSub.broadcast(
                session.id,
                {:announce,
                 %{
                   message:
                     trans("%{name} encountered an error and stopped", inter: [name: name]),
                   type: :error
                 }}
              )
          after
            LiveAdmin.PubSub.update_job(session.id, self(), progress: 1)
          end
        end)

        LiveAdmin.PubSub.broadcast(
          session.id,
          {:announce, %{message: trans("%{name} complete", inter: [name: name]), type: :info}}
        )
      end)

    LiveAdmin.PubSub.update_job(session.id, job.pid, progress: 0, label: to_string(name))

    {:noreply, push_navigate(socket, to: route_with_params(socket.assigns))}
  end

  def handle_event("toggle_select", params = %{"record_id" => id}, socket) do
    socket =
      if Map.has_key?(params, "selected") do
        update(socket, :selected, &[id | &1])
      else
        update(socket, :selected, &List.delete(&1, id))
      end

    {:noreply, socket}
  end

  def handle_event("toggle_select", params, socket) do
    records =
      case params["all"] do
        "on" -> socket.assigns.records.result |> elem(0) |> Enum.map(& &1.id)
        _ -> []
      end

    {:noreply, assign(socket, :selected, records)}
  end

  def handle_event("go", %{"page" => page, "per" => per}, socket = %{assigns: assigns}) do
    {:noreply,
     push_patch(socket,
       to:
         route_with_params(socket.assigns,
           params: index_link_params(assigns, page: page, per: per)
         )
     )}
  end

  def handle_event("add_filter", _, socket = %{assigns: assigns}) do
    new_search =
      socket.assigns.search
      |> LiveAdmin.View.parse_search()
      |> Enum.concat([{"*", "_"}])
      |> Enum.map_join(" ", fn
        {field, param} -> "#{field}:#{param}"
      end)

    {:noreply,
     push_patch(socket,
       to:
         route_with_params(socket.assigns,
           params: index_link_params(assigns, search: new_search)
         )
     )}
  end

  def handle_event("remove_filter", %{"index" => i}, socket = %{assigns: assigns}) do
    new_search =
      socket.assigns.search
      |> LiveAdmin.View.parse_search()
      |> List.delete_at(i)
      |> Enum.map_join(" ", fn
        {field, param} -> "#{field}:#{param}"
      end)

    {:noreply,
     push_patch(socket,
       to:
         route_with_params(socket.assigns,
           params: index_link_params(assigns, search: new_search)
         )
     )}
  end

  def handle_event("update_filters", %{"filters" => filter_params}, socket = %{assigns: assigns}) do
    new_search =
      filter_params
      |> Map.values()
      |> Enum.filter(fn p -> p["param"] != "" end)
      |> Enum.map_join(" ", fn
        %{"field" => "any", "param" => param} -> "*:#{param}"
        %{"field" => field, "param" => param} -> "#{field}:#{param}"
        {field, param} -> "#{field}:#{param}"
      end)

    {:noreply,
     push_patch(socket,
       to:
         route_with_params(socket.assigns,
           params: index_link_params(assigns, search: new_search)
         )
     )}
  end

  defp index_link_params(assigns, overrides \\ []) do
    assigns
    |> Map.take([:search, :page, :sort_attr, :sort_dir, :prefix, :per])
    |> Enum.into([])
    |> Keyword.merge(overrides)
  end
end
