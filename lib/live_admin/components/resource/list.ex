defmodule LiveAdmin.Components.Container.List do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import LiveAdmin
  import LiveAdmin.Components
  import LiveAdmin.View

  alias LiveAdmin.Resource
  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
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
          <span>list</span>
        </h1>
        <div class="contextual-actions">
          <.link
            navigate={route_with_params(assigns, segments: ["new"], params: [prefix: @prefix])}
            class="btn btn-primary"
          >
            {trans("Create")}
          </.link>
          <details class="btn-select">
            <summary>Run task</summary>
            <div class="settings-menu">
              <%= for task <- get_function_keys(@resource, @config, :tasks) do %>
                <span phx-click={JS.push("task", value: %{"name" => task}, page_loading: true)}>
                  {trans(humanize(task))}
                </span>
              <% end %>
            </div>
          </details>
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
                        <td><input type="checkbox" class="row-checkbox" /></td>
                        <%= for {field, type, _} <- Resource.fields(@resource, @config), {:ok, val} = Map.fetch(record, field) do %>
                          <td>
                            <span class="cell-content">{Resource.render(val, field, type, assigns)}</span>
                            <!-- Modal -->
                            <div class="modal" id={"modal-#{record_id}-#{field}"}>
                              <div
                                class="modal-content"
                                phx-click-away={JS.hide(to: "#modal-#{record_id}-#{field}")}
                              >
                                <div class="modal-header">
                                  <h3 class="modal-title">
                                    {record_label(record, @resource, @config)} > {field}
                                  </h3>
                                  <button
                                    class="modal-close"
                                    phx-click={JS.hide(to: "#modal-#{record_id}-#{field}")}
                                  >
                                    &times;
                                  </button>
                                </div>
                                <div class="modal-body">
                                  <div class="detail-section-content">
                                    {inspect(val, pretty: true)}
                                  </div>
                                </div>
                              </div>
                            </div>
                            <div class="cell-icons">
                              <span
                                class="expand-icon"
                                phx-click={
                                  JS.show(to: "#modal-#{record_id}-#{field}", display: "flex")
                                }
                              >
                                <svg
                                  width="14"
                                  height="14"
                                  viewBox="0 0 14 14"
                                  fill="none"
                                  xmlns="http://www.w3.org/2000/svg"
                                >
                                  <path
                                    d="M6 6L2 2M2 2L2 4M2 2L4 2"
                                    stroke="currentColor"
                                    stroke-width="1"
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                  />
                                  <path
                                    d="M8 6L12 2M12 2L12 4M12 2L10 2"
                                    stroke="currentColor"
                                    stroke-width="1"
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                  />
                                  <path
                                    d="M6 8L2 12M2 12L2 10M2 12L4 12"
                                    stroke="currentColor"
                                    stroke-width="1"
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                  />
                                  <path
                                    d="M8 8L12 12M12 12L12 10M12 12L10 12"
                                    stroke="currentColor"
                                    stroke-width="1"
                                    stroke-linecap="round"
                                    stroke-linejoin="round"
                                  />
                                </svg>
                              </span>
                              <span class="copy-icon">
                                <svg
                                  viewBox="0 0 24 24"
                                  fill="none"
                                  stroke="currentColor"
                                  stroke-width="2"
                                  title="Copy to clipboard"
                                >
                                  <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                                  <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                                </svg>
                              </span>
                            </div>
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

  @impl true
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

  @impl true
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

  @impl true
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
              {:success,
               trans("%{name} action run successfully on %{count} records",
                 inter: [name: name, count: length(records)]
               )}

            error_count ->
              {:error,
               trans(
                 "%{name} action failed on %{error_count} records (%{success_count} succeeeded)",
                 inter: [
                   name: name,
                   error_count: error_count,
                   success_count: length(records) - error_count
                 ]
               )}
          end

        LiveAdmin.PubSub.broadcast(session.id, {:job, %{pid: pid, progress: 1}})
        LiveAdmin.PubSub.broadcast(session.id, {:announce, %{message: message, type: type}})
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
