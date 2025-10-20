defmodule LiveAdmin.Components.Container.Single do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import LiveAdmin
  import LiveAdmin.View
  import LiveAdmin.Components

  alias LiveAdmin.Resource
  alias Phoenix.LiveView.JS
  alias PhoenixHTMLHelpers.Tag

  @impl true
  def render(assigns = %{record: nil}) do
    ~H"""
    <div>{trans("No record found")}</div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="content-header">
        <h1 class="content-title">
          {resource_title(@resource, @config)}
          <span>{record_label(@record, @resource, @config)}</span>
        </h1>
        <div class="contextual-actions">
          <%= if LiveAdmin.fetch_config(@resource, :update_with, @config) != false do %>
            <.link
              navigate={route_with_params(assigns, segments: [:edit, @record])}
              class="btn btn-primary"
            >
              {trans("Edit")}
            </.link>
          <% end %>
          <%= if LiveAdmin.fetch_config(@resource, :delete_with, @config) != false do %>
            <button
              class="btn btn-danger"
              data-confirm="Are you sure?"
              phx-click={
                JS.push("delete",
                  value: %{key: Map.fetch!(@record, LiveAdmin.primary_key!(@resource))},
                  page_loading: true,
                  target: @myself
                )
              }
            >
              {trans("Delete")}
            </button>
          <% end %>
          <details class="btn-select" phx-hook="Actions" id="actions-control">
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
        </div>
      </div>

      <div class="content-card">
        <div class="card-section">
          <div class="detail-view active">
            <div class="detail-grid">
              <%= for {field, type, _} <- Resource.fields(@resource, @config), renderable?(type), {:ok, val} = Map.fetch(@record, field) do %>
                <div class="detail-field">
                  <div class="detail-field-label">{trans(humanize(field))}</div>
                  <div class="detail-field-value">
                    <span>
                      {Resource.render(val, @record, field, type, val)}
                    </span>
                    <.expand_modal
                      record={@record}
                      resource={@resource}
                      field={field}
                      config={@config}
                    />
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp renderable?({_, {Ecto.Embedded, _}}), do: false
  defp renderable?(_), do: true

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
        params = %{"name" => name},
        socket = %{assigns: %{resource: resource, prefix: prefix, repo: repo, session: session}}
      ) do
    record =
      socket.assigns[:record] || Resource.find!(params["id"], resource, prefix, repo)

    {_, m, f, _, _} =
      LiveAdmin.fetch_function(resource, session, :actions, String.to_existing_atom(name))

    socket =
      case apply(m, f, [record, socket.assigns.session] ++ Map.get(params, "args", [])) do
        {:ok, record} ->
          LiveAdmin.PubSub.broadcast(
            session.id,
            {:announce,
             %{
               message: trans("Action %{name} succeeded", inter: [name: name]),
               type: :success
             }}
          )

          assign(socket, :record, record)

        {:error, error} ->
          LiveAdmin.PubSub.broadcast(
            session.id,
            {:announce,
             %{
               message:
                 trans("Action %{name} failed: %{error}", inter: [name: name, error: error]),
               type: :error
             }}
          )
      end

    {:noreply, socket}
  end
end
