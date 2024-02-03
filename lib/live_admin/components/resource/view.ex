defmodule LiveAdmin.Components.Container.View do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import LiveAdmin,
    only: [route_with_params: 1, route_with_params: 2, trans: 1, record_label: 3, trans: 2]

  import LiveAdmin.View, only: [field_class: 1]
  import LiveAdmin.Components

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
    <div id="view-page" class="view__container" phx-hook="IndexPage" phx-target={@myself}>
      <div class="resource__table">
        <dl>
          <%= for {field, type, _} <- Resource.fields(@resource, @config) do %>
            <% assoc_resource =
              LiveAdmin.associated_resource(
                Keyword.fetch!(@resource.__live_admin_config__(), :schema),
                field,
                @resources
              ) %>
            <% label = Resource.render(@record, field, @resource, assoc_resource, @session, @config) %>
            <dt class="field__label"><%= trans(humanize(field)) %></dt>
            <dd class={"field__#{field_class(type)}"}>
              <%= if assoc_resource && Map.fetch!(@record, field) do %>
                <.link
                  class="field__assoc--link"
                  target="_blank"
                  navigate={
                    route_with_params(assigns,
                      resource_path: elem(assoc_resource, 0),
                      segments: [Map.fetch!(@record, field)]
                    )
                  }
                >
                  <%= label %>
                </.link>
              <% else %>
                <%= label %>
              <% end %>
            </dd>
          <% end %>
        </dl>
        <div class="form__actions">
          <%= if LiveAdmin.fetch_config(@resource, :update_with, @config) != false do %>
            <.link
              navigate={route_with_params(assigns, segments: [:edit, @record])}
              class="resource__action--btn"
            >
              <%= trans("Edit") %>
            </.link>
          <% end %>
          <%= if LiveAdmin.fetch_config(@resource, :delete_with, @config) != false do %>
            <button
              class="resource__action--danger"
              data-confirm="Are you sure?"
              phx-click={
                JS.push("delete",
                  value: %{key: Map.fetch!(@record, LiveAdmin.primary_key!(@resource))},
                  page_loading: true,
                  target: @myself
                )
              }
            >
              <%= trans("Delete") %>
            </button>
          <% end %>
          <.dropdown
            :let={action}
            orientation={:up}
            label={trans("Run action")}
            items={LiveAdmin.fetch_config(@resource, :actions, @config)}
            disabled={Enum.empty?(LiveAdmin.fetch_config(@resource, :actions, @config))}
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
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "delete",
        %{"key" => key},
        %{
          assigns: %{
            resource: resource,
            session: session,
            config: config
          }
        } = socket
      ) do
    socket =
      key
      |> Resource.find!(resource, socket.assigns.prefix, socket.assigns.repo)
      |> Resource.delete(resource, session, socket.assigns.repo, config)
      |> case do
        {:ok, record} ->
          socket
          |> put_flash(
            :info,
            trans("Deleted %{label}", inter: [label: record_label(record, resource, config)])
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
        socket = %{assigns: %{resource: resource, prefix: prefix, repo: repo, session: session}}
      ) do
    record =
      socket.assigns[:record] || Resource.find!(params["id"], resource, prefix, repo)

    action_name = String.to_existing_atom(action)

    {m, f, a} =
      resource
      |> LiveAdmin.fetch_config(:actions, session)
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
