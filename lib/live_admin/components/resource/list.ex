defmodule LiveAdmin.Components.Container.List do
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
              list_link_params(assigns),
              assigns.session,
              assigns.repo,
              assigns.config
            )

          if Enum.any?(records) do
            {:ok, %{records: {records, count}}}
          else
            {:error, :no_results}
          end
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
          <span>{trans("List")}</span>
        </h1>
        <div class="contextual-actions">
          <.link
            navigate={route_with_params(assigns, segments: ["new"], params: [prefix: @prefix])}
            class="btn btn-primary"
          >
            {trans("Create")}
          </.link>
          <%= if Enum.any?(@selected) && LiveAdmin.fetch_config(@resource, :delete_with, @config) != false do %>
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
            <details class="btn-select" id="actions-control">
              <summary>Run action</summary>
              <div class="settings-menu">
                <%= for action <- get_function_keys(@resource, @config, :actions), {name, _, _, arity, docs} = LiveAdmin.fetch_function(@resource, @session, :actions, action) do %>
                  <.function_control
                    name={action}
                    type="action"
                    extra_arg_count={arity - 2}
                    docs={docs}
                    target={@myself}
                  />
                <% end %>
              </div>
            </details>
          <% else %>
            <details class="btn-select">
              <summary>Run task</summary>
              <div class="settings-menu">
                <%= for task <- get_function_keys(@resource, @config, :tasks), {name, _, _, arity, docs} = LiveAdmin.fetch_function(@resource, @session, :tasks, task) do %>
                  <.function_control
                    name={task}
                    type="task"
                    extra_arg_count={arity - 2}
                    docs={docs}
                    target={@myself}
                  />
                <% end %>
              </div>
            </details>
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
            <div class="table-container">
              <table class="data-table">
                <thead>
                  <tr>
                    <th><input type="checkbox" class="row-checkbox" title="Select all" /></th>
                    <%= for {field, _, _} <- Resource.fields(@resource, @config) do %>
                      <th class={sort_class(field, @sort_attr, @sort_dir)}>
                        <.link patch={
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
                        <%= for {field, type, _} <- Resource.fields(@resource, @config), {:ok, val} = Map.fetch(record, field) do %>
                          <td class="table-cell">
                            <span class="cell-content">
                              {Resource.render(val, record, field, type, assigns)}
                            </span>
                            <.expand_modal
                              id={"expand-#{record_id}-#{field}"}
                              title={record_label(record, @resource, @config)}
                              value={val}
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
                          params: list_link_params(assigns, page: @page - 1)
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
                          params: list_link_params(assigns, page: @page + 1)
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
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp safe_render(nil), do: ""

  defp safe_render(list) when is_list(list), do: inspect(list, pretty: true)

  defp safe_render(val) do
    to_string(val)
  rescue
    e -> inspect(val, pretty: true)
  end

  defp list_error(assigns = %{failed: {:error, :no_results}}) do
    ~H"""
    <div class="list__error">
      {trans("No results for this page with current filters.")}
      <p>
        <button
          class="resource__action--btn"
          phx-click={
            JS.show(
              to: "#settings-modal",
              transition: {"ease-in duration-300", "opacity-0", "opacity-100"}
            )
          }
        >
          {trans("Edit view")}
        </button>
      </p>
    </div>
    """
  end

  defp list_error(assigns) do
    ~H"""
    {trans("Error")}
    """
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
        socket = %{assigns: %{resource: resource, session: session, prefix: prefix, repo: repo}}
      ) do
    {_, m, f, _, _} =
      LiveAdmin.fetch_function(resource, session, :actions, String.to_existing_atom(name))

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
              record -> apply(m, f, [record, session] ++ Map.get(params, "args", []))
            end

            LiveAdmin.PubSub.update_job(session.id, self(),
              progress: idx / Enum.count(socket.assigns.selected),
              label: name
            )
          rescue
            error -> Logger.error(inspect(error))
          after
            LiveAdmin.PubSub.update_job(session.id, self(), progress: 1)
          end
        end)
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

  def handle_event("go", %{"page" => page, "per" => per}, socket = %{assigns: assigns}) do
    {:noreply,
     push_patch(socket,
       to:
         route_with_params(socket.assigns,
           params: list_link_params(assigns, page: page, per: per)
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
           params: list_link_params(assigns, search: new_search)
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
           params: list_link_params(assigns, search: new_search)
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
           params: list_link_params(assigns, search: new_search)
         )
     )}
  end

  def handle_event(
        "action",
        params = %{"name" => name, "ids" => ids},
        socket = %{
          assigns: %{
            session: session,
            resource: resource,
            repo: repo,
            config: config
          }
        }
      ) do
    task_def =
      if name == "delete" do
        {"delete", Resource, :delete, [resource, session, repo, config]}
      else
        {label, mod, func, _, _} =
          LiveAdmin.fetch_function(
            resource,
            session,
            :actions,
            String.to_existing_atom(name)
          )

        {label, mod, func, [session | Map.get(params, "args", [])]}
      end

    socket =
      socket
      |> handle_action(name, ids, task_def)
      |> push_navigate(
        to: route_with_params(socket.assigns, params: list_link_params(socket.assigns))
      )

    {:noreply, socket}
  end

  defp handle_action(
         socket = %{assigns: %{resource: resource, prefix: prefix, repo: repo, config: config}},
         name,
         [id],
         {_, mod, func, args}
       ) do
    record = Resource.find(id, resource, prefix, repo)

    apply(mod, func, [record | args])
    |> case do
      {:ok, record} ->
        put_flash(
          socket,
          :success,
          trans(
            "%{name} action succeeded on %{resource} %{label}",
            inter: [
              name: name,
              resource: resource_title(resource, config),
              label: record_label(record, resource, config)
            ]
          )
        )

      {:error, message} ->
        put_flash(
          socket,
          :error,
          trans(
            "%{name} action failed on %{resource} %{label}: '%{message}'",
            inter: [
              name: name,
              message: message,
              resource: resource_title(resource, config),
              label: record_label(record, resource, config)
            ]
          )
        )
    end
  end

  defp handle_action(
         socket = %{assigns: %{session: session, prefix: prefix, resource: resource, repo: repo}},
         name,
         ids,
         {label, mod, func, args}
       ) do
    Task.Supervisor.async_nolink(
      LiveAdmin.Task.Supervisor,
      fn ->
        pid = self()

        LiveAdmin.PubSub.broadcast(session.id, {:job, %{pid: pid, progress: 0, label: label}})

        records = Resource.all(ids, resource, prefix, repo)

        {type, message} =
          records
          |> Enum.with_index()
          |> Enum.reduce(0, fn {record, i}, failed_count ->
            try do
              case apply(mod, func, [record | args]) do
                {:ok, _} -> failed_count
                {:error, _} -> failed_count + 1
              end
            rescue
              _ -> failed_count + 1
            after
              LiveAdmin.PubSub.broadcast(
                session.id,
                {:job, %{pid: pid, progress: (i + 1) / length(records)}}
              )
            end
          end)
          |> case do
            0 ->
              LiveAdmin.PubSub.announce(
                session.id,
                :success,
                trans("%{name} action run successfully on %{count} records",
                  inter: [name: name, count: length(records)]
                )
              )

            error_count ->
              LiveAdmin.PubSub.announce(
                session.id,
                :error,
                trans(
                  "%{name} action failed on %{error_count} records (%{success_count} succeeeded)",
                  inter: [
                    name: name,
                    error_count: error_count,
                    success_count: length(records) - error_count
                  ]
                )
              )
          end

        LiveAdmin.PubSub.update_job(session.id, pid, progress: 1)
      end,
      timeout: :infinity
    )

    socket
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
