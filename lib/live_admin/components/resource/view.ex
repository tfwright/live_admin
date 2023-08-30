defmodule LiveAdmin.Components.Container.View do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin,
    only: [route_with_params: 1, route_with_params: 2, trans: 1, record_label: 2, trans: 2]

  import LiveAdmin.View, only: [field_class: 1]

  alias LiveAdmin.Resource
  alias Phoenix.LiveView.JS

  @impl true
  def render(assigns = %{record: nil}) do
    ~H"""
    <div><%= trans("No record found") %></div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="resource__view">
      <div class="resource__table">
        <dl>
          <%= for {field, type, _} <- Resource.fields(@resource) do %>
            <% assoc_resource =
              LiveAdmin.associated_resource(
                @resource.__live_admin_config__(:schema),
                field,
                @resources
              ) %>
            <% label = Resource.render(@record, field, @resource, assoc_resource, @session) %>
            <dt class="field__label"><%= trans(humanize(field)) %></dt>
            <dd class={"field__#{field_class(type)}"}>
              <%= if assoc_resource && Map.fetch!(@record, field) do %>
                <%= live_redirect(label,
                  to:
                    route_with_params(assigns,
                      resource_path: elem(assoc_resource, 0),
                      segments: [Map.fetch!(@record, field)]
                    ),
                  class: "resource__action--btn"
                ) %>
              <% else %>
                <%= label %>
              <% end %>
            </dd>
          <% end %>
        </dl>
        <div class="form__actions">
          <%= live_redirect(trans("Edit"),
            to: route_with_params(assigns, segments: [:edit, @record]),
            class: "resource__action--btn"
          ) %>
          <%= if @resource.__live_admin_config__(:delete_with) != false do %>
            <button
              class="resource__action--danger"
              data-confirm="Are you sure?"
              phx-click={
                JS.push("delete", value: %{id: @record.id}, page_loading: true, target: @myself)
              }
            >
              <%= trans("Delete") %>
            </button>
          <% end %>
          <div class="resource__action--drop">
            <button
              class={"resource__action#{if Enum.empty?(@resource.__live_admin_config__(:actions)), do: "--disabled", else: "--btn"}"}
              disabled={if Enum.empty?(@resource.__live_admin_config__(:actions)), do: "disabled"}
            >
              <%= trans("Run action") %>
            </button>
            <nav>
              <ul>
                <%= for action <- @resource.__live_admin_config__(:actions) do %>
                  <li>
                    <button
                      class="resource__action--link"
                      data-confirm="Are you sure?"
                      phx-click={
                        JS.push("action",
                          value: %{id: @record.id, action: action},
                          target: @myself,
                          page_loading: true
                        )
                      }
                    >
                      <%= action |> to_string() |> humanize() %>
                    </button>
                  </li>
                <% end %>
              </ul>
            </nav>
          </div>
        </div>
      </div>
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
          |> put_flash(
            :info,
            trans("Deleted %{label}", inter: [label: record_label(record, resource)])
          )
          |> push_navigate(to: route_with_params(socket.assigns))

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
        params = %{"action" => action},
        socket = %{assigns: %{resource: resource, prefix: prefix, repo: repo}}
      ) do
    record = socket.assigns[:record] || Resource.find!(params["id"], resource, prefix, repo)

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
        {:ok, record} ->
          socket
          |> push_event("success", %{
            msg: trans("%{action} succeeded", inter: [action: action])
          })
          |> assign(:record, record)

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
end
