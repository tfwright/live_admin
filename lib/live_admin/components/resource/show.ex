defmodule LiveAdmin.Components.Container.Show do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import LiveAdmin
  import LiveAdmin.View
  import LiveAdmin.Components

  alias LiveAdmin.Resource
  alias Phoenix.LiveView.JS

  @impl true
  def render(assigns = %{record: nil}) do
    ~H"""
    <div>{trans("No record found")}</div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="show-page" phx-hook="Show">
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
          <%= if Enum.any?(LiveAdmin.fetch_config(@resource, :actions, @config)) do %>
            <.drop_down
              :let={action}
              id="action-select"
              items={
                @resource
                |> get_function_keys(@config, :actions)
                |> Enum.map(&LiveAdmin.fetch_function(@resource, @config, :actions, &1))
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
          <% end %>
        </div>
      </div>

      <div class="content-card">
        <.detail_view
          id="main"
          fields={Resource.fields(@resource, @config)}
          record={@record}
          title={record_label(@record, @resource, @config)}
          resource={@resource}
          resources={@resources}
          base_path={@base_path}
          prefix={@prefix}
          config={@config}
          session={@session}
        />
      </div>
    </div>
    """
  end

  attr(:last, :integer, default: 0)
  attr(:current, :integer, default: 0)
  attr(:id, :string, required: true)
  attr(:record, :map, required: true)
  attr(:resource, :map, required: true)
  attr(:resources, :list, required: true)
  attr(:base_path, :string, required: true)
  attr(:prefix, :any, default: nil)
  attr(:title, :string, required: true)
  attr(:fields, :any, default: [])
  attr(:embeds, :any, default: [])
  attr(:session, LiveAdmin.Session, required: true)
  attr(:config, :list, required: true)

  def detail_view(assigns) do
    assigns =
      assign(
        assigns,
        :embeds,
        Enum.filter(assigns.fields, fn
          {field, {_, {Ecto.Embedded, _}}, _} -> Map.fetch!(assigns.record, field)
          _ -> false
        end)
      )

    ~H"""
    <div class="detail-view" id={if @id != "main", do: "#{@id}_#{@current}", else: "main"}>
      <%= if Enum.any?(@embeds) || @last > 0 do %>
        <div class="tabs">
          <%= if @id == "main" do %>
            <a href="#main" id="main-link"></a>
          <% end %>
          <%= for {field, _, _} <- @embeds, @record |> Map.fetch!(field) |> List.wrap() |> Enum.any? do %>
            <a href={"##{@id}_#{field}_0"}>{trans(humanize(field))}</a>
          <% end %>
          <%= if @last > 0 do %>
            <%= for n <- 0..@last do %>
              <a href={"##{@id}_#{n}"}>{n}</a>
            <% end %>
          <% end %>
        </div>
      <% end %>
      <div class="card-section">
        <div class="detail-grid">
          <%= for {field, type, _} <- @fields, renderable?(type) do %>
            <div class="detail-field">
              <div class="detail-field-label">{trans(humanize(field))}</div>
              <div class="detail-field-value">
                <span>
                  {Resource.render(@record, field, type, @resource, @config, @session)}
                </span>
                <%= if (assoc_key = assoc_resource_key(@resource, field, @resources, @config)) && Map.fetch!(@record, field) do %>
                  <a
                    class="assoc-link-icon"
                    href={
                      route_with_params(assigns,
                        resource_path: assoc_key,
                        segments: [Map.fetch!(@record, field)]
                      )
                    }
                    target="_blank"
                  >
                    <svg
                      width="14"
                      height="14"
                      viewBox="0 0 14 14"
                      fill="none"
                      xmlns="http://www.w3.org/2000/svg"
                    >
                      <path
                        d="M5.5 2H3C2.44772 2 2 2.44772 2 3V11C2 11.5523 2.44772 12 3 12H11C11.5523 12 12 11.5523 12 11V8.5"
                        stroke="currentColor"
                        stroke-width="1.2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      />
                      <path
                        d="M8 2H12V6"
                        stroke="currentColor"
                        stroke-width="1.2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      />
                      <path
                        d="M12 2L7 7"
                        stroke="currentColor"
                        stroke-width="1.2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      />
                    </svg>
                  </a>
                <% end %>
                <.expand_modal
                  id={"#{@id}-#{field}-#{@current}-expand"}
                  title={@title}
                  field={field}
                  value={Map.fetch!(@record, field)}
                />
              </div>
            </div>
          <% end %>
        </div>
      </div>
      <%= for {field, {_, {_, %{related: schema}}}, _} <- @embeds, embed = Map.fetch!(@record, field), list = List.wrap(embed) do %>
        <%= for {record, index} <- Enum.with_index(list) do %>
          <.detail_view
            id={"#{@id}_#{field}"}
            fields={Enum.map(schema.__schema__(:fields), &{&1, schema.__schema__(:type, &1), []})}
            record={record}
            title={trans(humanize(field))}
            current={index}
            last={Enum.count(list) - 1}
            resource={@resource}
            resources={@resources}
            base_path={@base_path}
            prefix={@prefix}
            config={@config}
            session={@session}
          />
        <% end %>
      <% end %>
    </div>
    """
  end

  defp renderable?({_, {Ecto.Embedded, _}}), do: false
  defp renderable?(_), do: true

  defp assoc_resource_key(resource, field, resources, config) do
    schema = LiveAdmin.fetch_config(resource, :schema, config)
    LiveAdmin.associated_resource(schema, field, resources, :key)
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
      |> Resource.find!(resource, socket.assigns.prefix, socket.assigns.repo, config)
      |> Resource.delete(resource, session, socket.assigns.repo, config)
      |> case do
        {:ok, _record} ->
          LiveAdmin.PubSub.announce(
            session.id,
            :success,
            trans("Record deleted")
          )

          push_navigate(socket, to: route_with_params(socket.assigns))

        {:error, message} ->
          LiveAdmin.PubSub.announce(
            session.id,
            :error,
            message
          )

          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("action", params = %{"name" => name}, socket) do
    %{resource: resource, session: session, record: record, config: config} = socket.assigns

    {_, m, f, _, _} =
      LiveAdmin.fetch_function(resource, config, :actions, String.to_existing_atom(name))

    socket =
      case apply(m, f, [record, session] ++ Map.get(params, "args", [])) do
        {:ok, record} ->
          LiveAdmin.PubSub.announce(
            session.id,
            :success,
            trans("%{name} succeeded", inter: [name: name])
          )

          assign(socket, :record, record)

        {:error, message} ->
          LiveAdmin.PubSub.announce(
            session.id,
            :error,
            message
          )

          socket
      end

    {:noreply, socket}
  end
end
