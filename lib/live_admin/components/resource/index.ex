defmodule LiveAdmin.Components.Container.Index do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import LiveAdmin,
    only: [
      record_label: 3,
      resource_title: 2,
      route_with_params: 2,
      trans: 1,
      trans: 2
    ]

  import LiveAdmin.Components
  import LiveAdmin.View, only: [get_function_keys: 3]

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
            phx-click={
              JS.show(to: "#settings-modal")
              |> JS.add_class("hidden", to: "#settings-modal > div > div:nth-child(2)")
              |> JS.remove_class("hidden", to: "#settings-modal > div > div:nth-child(3)")
              |> JS.remove_class("opacity-30", to: "#settings-modal .modal__title:nth-child(2)")
              |> JS.add_class("opacity-30", to: "#settings-modal .modal__title:nth-child(1)")
            }
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
                    {trans(humanize(field))}
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
                        {Resource.render(
                        record,
                        field,
                        @resource,
                        assoc_resource,
                        @session,
                        @config
                        )}
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
                <td class="p-10" colspan={@resource |> Resource.fields(@config) |> Enum.count()}>
                  <%= if @records.loading do %>
                    <div class="spinner" />
                  <% else %>
                    <.list_error failed={@records.failed} />
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
                    to: "#settings-modal",
                    transition: {"ease-in duration-300", "opacity-0", "opacity-100"}
                  )
                }
              >
                {min((@page - 1) * @per + 1, elem(@records.result, 1))}-{min(
                @page * @per,
                elem(@records.result, 1)
                )}/{elem(@records.result, 1)}
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
                    {trans("Delete")}
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
                {elem(@job, 0)}: {elem(@job, 1)}
              </div>
            <% end %>
          </div>
        </div>
      </div>
      <.modal id="settings-modal">
        <div class="modal__tabs">
          <a
            class="modal__title"
            phx-click={
              JS.add_class("hidden", to: "#settings-modal > div > div:nth-child(3)")
              |> JS.remove_class("hidden", to: "#settings-modal > div > div:nth-child(2)")
              |> JS.remove_class("opacity-30")
              |> JS.add_class("opacity-30", to: "#settings-modal .modal__title:nth-child(2)")
            }
          >
            {trans("Page")}
          </a>
          <a
            class="modal__title opacity-30"
            phx-click={
              JS.add_class("hidden", to: "#settings-modal > div > div:nth-child(2)")
              |> JS.remove_class("hidden", to: "#settings-modal > div > div:nth-child(3)")
              |> JS.remove_class("opacity-30")
              |> JS.add_class("opacity-30", to: "#settings-modal .modal__title:nth-child(1)")
            }
          >
            {trans("Filters")}
          </a>
        </div>
        <div>
          <form phx-submit="go" phx-target={@myself}>
            <div>
              <label>{trans("Number")}</label>
              <input type="number" name="page" value={@page} />
            </div>
            <div>
              <label>{trans("Size")}</label>
              <input type="number" name="per" value={@per} />
            </div>
            <input type="submit" value={trans("Go")} phx-click={JS.hide(to: "#settings-modal")} />
          </form>
        </div>
        <div class="hidden">
          <form phx-submit="update_filters" phx-target={@myself} id="list-filters">
            <%= for {{col, val}, i} <- @search |> LiveAdmin.View.parse_search() |> Enum.with_index() do %>
              <div>
                <div>
                  <a
                    href="#"
                    class="button__remove"
                    phx-click={
                      JS.push("remove_filter",
                        target: @myself,
                        page_loading: true,
                        value: %{index: i}
                      )
                    }
                  />
                </div>
                <div>
                  <select name={"filters[#{i}][field]"}>
                    <option selected={is_nil(col)}>{trans("any")}</option>
                    <%= for {field, _, _} <- Resource.fields(@resource, @config) do %>
                      <option selected={col == to_string(field)}>{to_string(field)}</option>
                    <% end %>
                  </select>
                  <select name={"filters[#{i}][operator]"} disabled="disabled">
                    <option>contains</option>
                  </select>
                  <input type="text" name={"filters[#{i}][param]"} value={val} />
                </div>
              </div>
            <% end %>
            <div>
              <a
                href="#"
                class="button__add"
                phx-click={JS.push("add_filter", target: @myself, page_loading: true)}
              />
            </div>
            <input type="submit" value={trans("Apply")} phx-click={JS.hide(to: "#settings-modal")} />
          </form>
        </div>
      </.modal>
    </div>
    """
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
