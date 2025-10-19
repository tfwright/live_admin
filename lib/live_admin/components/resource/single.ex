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
          <button class="btn btn-danger">
            <span>Delete</span>
          </button>
          <details class="btn-select" phx-hook="Actions" id="actions-control">
            <summary>Run action</summary>
            <div class="settings-menu">
              <%= for {action, _} <- LiveAdmin.fetch_config(@resource, :actions, @config), {name, _, _, arity, docs} = LiveAdmin.fetch_function(@resource, @session, :actions, action), extra_arg_count = (arity - 2), {:ok, modalize} = {:ok, extra_arg_count > 0 || Enum.any?(docs)} do %>
                <%= if modalize do %>
                  <.modal id={"#{action}-modal"}>
                    <:title>{name |> to_string() |> humanize()}</:title>
                    <.form
                      for={Phoenix.Component.to_form(%{})}
                      phx-submit={
                        JS.dispatch("phx:page-loading-start") |> JS.dispatch("live_admin:action") |> JS.hide(to: "##{action}-modal")
                      }
                      class="form-line"
                    >
                      <%= for {_lang, doc} <- docs do %>
                        <div class="docs">{doc}</div>
                      <% end %>
                      <input type="hidden" name="name" value={action} />
                      <%= if extra_arg_count > 0 do %>
                        <h2 class="form-title">Arguments</h2>
                        <%= for num <- 1..extra_arg_count do %>
                          <div class="form-group">
                              <label>{num}</label>
                              <textarea class="form-textarea" name="args[]" required></textarea>
                          </div>
                        <% end %>
                      <% end %>
                      <div class="button-group">
                          <button type="submit" class="btn btn-primary">Submit</button>
                          <button type="button" class="btn btn-danger">Cancel</button>
                      </div>
                    </.form>
                  </.modal>
                <% end %>
                <span
                  phx-click={
                    if modalize,
                      do: JS.show(to: "##{action}-modal", display: "flex"),
                      else: JS.dispatch("live_admin:action")
                  }
                  data-confirm={if modalize, do: nil, else: trans("Are you sure you?")}
                >
                  {trans(humanize(action))}
                </span>
              <% end %>
            </div>
          </details>
        </div>
      </div>

      <div class="content-card">
        <div class="card-section">
          <div class="detail-view active">
            <div class="detail-grid">
              <%= for {field, type, _} <- Resource.fields(@resource, @config), renderable?(type), val = Map.fetch!(@record, field) do %>
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
        params = %{"name" => action},
        socket = %{assigns: %{resource: resource, prefix: prefix, repo: repo, session: session}}
      ) do
    record =
      socket.assigns[:record] || Resource.find!(params["id"], resource, prefix, repo)

    {_, m, f, _, _} =
      LiveAdmin.fetch_function(resource, session, :actions, String.to_existing_atom(action))

    socket =
      case apply(m, f, [record, socket.assigns.session] ++ Map.get(params, "args", [])) do
        {:ok, record} ->
          LiveAdmin.PubSub.broadcast(
            session.id,
            {:announce,
             %{
               message:
                 trans("%{name} action succeeded", inter: [name: action]),
               type: :success
             }}
          )

          assign(socket, :record, record)



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
      |> push_event("page-loading-stop", %{})

    {:noreply, socket}
  end
end
