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
    fields =
      assigns.resource
      |> Resource.fields(assigns.config)
      |> Enum.map(fn {field, type, _} ->
        {field, render(field, type, assigns)}
      end)

    assigns = assign(assigns, :fields, fields)

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
          <button class="btn btn-danger">
            <span>Delete</span>
          </button>
          <details class="btn-select">
            <summary>Run action</summary>
            <div class="settings-menu">
              <%= for {action, _} <- LiveAdmin.fetch_config(@resource, :actions, @config) do %>
                <a>{trans(humanize(action))}</a>
              <% end %>
            </div>
          </details>
        </div>
      </div>

      <div class="content-card">
        <div class="card-section">
          <div class="detail-view active">
            <div class="detail-grid">
              <%= for {field, {:inline, val}} <- @fields do %>
                <div class="detail-field">
                  <div class="detail-field-label">{trans(humanize(field))}</div>
                  <div class="detail-field-value">{val}</div>
                </div>
              <% end %>
            </div>

            <%= for {field, {:block, val}} <- @fields do %>
              <div class="detail-section">
                <h3 class="detail-section-title">{trans(humanize(field))}</h3>
                <div class="detail-section-content">{val}</div>
              </div>
            <% end %>
          </div>
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
        params = %{"name" => action},
        socket = %{assigns: %{resource: resource, prefix: prefix, repo: repo, session: session}}
      ) do
    record =
      socket.assigns[:record] || Resource.find!(params["id"], resource, prefix, repo)

    {_, m, f, _, _} =
      LiveAdmin.fetch_function(resource, session, :actions, String.to_existing_atom(action))

    socket =
      case apply(m, f, [record, socket.assigns.session] ++ Map.get(params, "args", [])) do
        {:ok, result} ->
          if is_struct(result, Keyword.fetch!(resource.__live_admin_config__(), :schema)) do
            socket
            |> push_event("success", %{
              msg: trans("%{action} succeeded", inter: [action: action])
            })
            |> assign(:record, record)
          else
            socket
            |> push_event("success", %{msg: result})
            |> assign(
              :record,
              Resource.find!(
                Map.fetch!(record, LiveAdmin.primary_key!(resource)),
                resource,
                prefix,
                repo
              )
            )
          end

        {:error, error} ->
          push_event(
            socket,
            "error",
            %{
              msg:
                trans("%{action} failed: %{error}",
                  inter: [
                    action: action,
                    error: error
                  ]
                )
            }
          )
      end

    {:noreply, socket}
  end

  defp render(field, type, assigns) when type in [:id, :binary_id] do
    val =
      assigns.resource
      |> LiveAdmin.fetch_config(:schema, assigns.config)
      |> LiveAdmin.associated_resource(
        field,
        assigns.resources
      )
      |> case do
        nil ->
          Map.fetch!(assigns.record, field)
        assoc_resource ->
          Tag.content_tag(:a,
          record_label(
            Map.fetch!(
              assigns.record,
              assigns.resource.__live_admin_config__()
              |> Keyword.fetch!(:schema)
              |> LiveAdmin.Resource.get_assoc_name!(field)
            ),
            elem(assoc_resource, 1),
            assigns.config
          ), href:
              route_with_params(assigns,
                resource_path: elem(assoc_resource, 0),
                segments: [Map.fetch!(assigns.record, field)]
              ), class: "resource-link")
      end

    {:inline, val}
  end

  defp render(field, {_, {Ecto.Embedded, _}}, %{record: record}),
    do: {:block, record |> Map.fetch!(field) |> safe_render()}

  defp render(field, :map, %{record: record}),
    do: {:block, record |> Map.fetch!(field) |> safe_render()}

  defp render(field, _, %{record: record}) do
    record
    |> Map.fetch!(field)
    |> case do
      string when is_binary(string) and byte_size(string) < 255 ->
        {:inline, string}

      list when is_list(list) ->
        {:inline, safe_render(list)}

      other ->
        other
        |> inspect()
        |> case do
          string when byte_size(string) < 255 -> {:inline, string}
          string -> {:block, string}
        end
    end
  end

  defp safe_render(nil), do: ""

  defp safe_render(list) when is_list(list), do: inspect(list, pretty: true)

  defp safe_render(val) do
    to_string(val)
  rescue
    e -> inspect(val, pretty: true)
  end
end
