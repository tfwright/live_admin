defmodule LiveAdmin.Components.Container.Form do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  use PhoenixHTMLHelpers

  import LiveAdmin.Components
  import LiveAdmin.ErrorHelpers
  import LiveAdmin
  import LiveAdmin.View

  alias __MODULE__.{ArrayInput, MapInput, SearchSelect}
  alias LiveAdmin.Resource
  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns = %{record: record}, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:enabled, false)
      |> assign(:changeset, Resource.change(assigns.resource, record, assigns.config))

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:changeset, Resource.change(assigns.resource, assigns.config))

    {:ok, socket}
  end

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
          <%= if assigns[:record] do %>
            <span>{record_label(@record, @resource, @config)}</span>
          <% else %>
          <span>{trans("create")}</span>
          <% end %>
        </h1>
      </div>

      <div class="content-card">
        <div class="card-section">
          <div class="edit-view">
            <.form
              :let={f}
              for={@changeset}
              as={:params}
              phx-change="validate"
              phx-submit={@action}
              phx-target={@myself}
              class="form-grid"
            >
              <%= for {field, type, opts} <- Resource.fields(@resource, @config) do %>
                <div class="form-field">
                  <div class="form-label">
                    {label(f, field, field |> humanize() |> trans())}
                  </div>
                  <%= if supported_type?(type) do %>
                    <.input
                      form={f}
                      type={type}
                      field={field}
                      resource={@resource}
                      resources={@resources}
                      session={@session}
                      prefix={@prefix}
                      repo={@repo}
                      config={@config}
                      disabled={false}
                    />
                  <% else %>
                    {textarea(f, field,
                      rows: 1,
                      disabled: true,
                      value: f |> input_value(field) |> inspect()
                    )}
                  <% end %>
                  {error_tag(f, field)}
                </div>
              <% end %>

                <div class="form-actions">
                  <.link
                    class="btn btn-danger"
                    data-confirm="Are you sure?"
                    navigate={if assigns[:record], do: route_with_params(assigns, segments: [@record]), else: route_with_params(assigns)}
                  >
                    {trans("Cancel")}
                  </.link>
                  <input type="submit" class="btn btn-primary" value={trans("Save")} />
                </div>
            </.form>
                </div>
        </div>
      </div>
    </div>
    """
  end



  # <div class="detail-section">
  #   <div class="form-field">
  #     <label class="form-label" for="edit-description">Description</label>
  #     <textarea id="edit-description" class="form-textarea">This task involves designing and implementing the complete database schema for Project Alpha. The schema has been optimized for performance and scalability, incorporating best practices for data normalization and indexing strategies.</textarea>
  #   </div>
  # </div>

  # <div class="detail-section">
  #   <div class="form-field">
  #     <label class="form-label" for="edit-notes">Notes</label>
  #     <textarea id="edit-notes" class="form-textarea">Schema optimized - All tables have been reviewed and optimized. Foreign key relationships established. Indexes created for frequently queried columns. Migration scripts prepared for deployment.</textarea>
  #   </div>
  # </div>

  @impl true
  def handle_event(
        "validate",
        %{"params" => params},
        socket = %{
          assigns: %{resource: resource, changeset: changeset, session: session, config: config}
        }
      ) do
    changeset = validate(resource, changeset, params, session, config)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event(
        "create",
        %{"params" => params},
        %{assigns: %{resource: resource, session: session, repo: repo, config: config}} = socket
      ) do
    socket =
      case Resource.create(resource, params, session, repo, config) do
        {:ok, _} ->
          socket
          |> put_flash(:info, trans("Record successfully added"))
          |> push_navigate(
            to: route_with_params(socket.assigns, params: [prefix: socket.assigns.prefix])
          )

        {:error, changeset} ->
          assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "update",
        %{"params" => params},
        %{assigns: %{resource: resource, session: session, record: record, config: config}} =
          socket
      ) do
    socket =
      Resource.update(record, resource, params, session, config)
      |> case do
        {:ok, _} ->
          socket
          |> put_flash(:info, trans("Record successfully updated"))
          |> push_navigate(to: route_with_params(socket.assigns, segments: [record]))

        {:error, changeset} ->
          assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end

  # defp input(assigns = %{type: {_, {Ecto.Embedded, _}}}) do
  #   ~H"""
  #   <.embed
  #     id={input_id(@form, @field)}
  #     type={@type}
  #     disabled={@disabled}
  #     form={@form}
  #     field={@field}
  #     resource={@resource}
  #     resources={@resource}
  #     session={@session}
  #     prefix={@prefix}
  #     repo={@repo}
  #     config={@config}
  #   />
  #   """
  # end

  defp input(assigns = %{type: id}) when id in [:id, :binary_id] do
    assigns =
      assign(
        assigns,
        :associated_resource,
        associated_resource(
          LiveAdmin.fetch_config(assigns.resource, :schema, assigns.session),
          assigns.field,
          assigns.resources,
          :resource
        )
      )

    ~H"""
    <%= if @associated_resource do %>
        <.live_component
          module={SearchSelect}
          id={input_id(@form, @field)}
          form={@form}
          field={@field}
          disabled={@disabled}
          resource={@associated_resource}
          session={@session}
          prefix={@prefix}
          repo={@repo}
          config={@config}
        />
    <% else %>
      <%= if assigns[:record] do %>
        <textarea name={@form[@field].name} class="form-textarea" disabled={@form.data |> Ecto.primary_key() |> Keyword.keys() |> Enum.member?(@field)}>{@form[@field].value}</textarea>
      <% end %>
    <% end %>
    """
  end

  defp input(assigns = %{type: {:array, :string}}) do
    ~H"""
    <.live_component
      module={ArrayInput}
      id={input_id(@form, @field)}
      form={@form}
      field={@field}
      disabled={@disabled}
    />
    """
  end

  defp input(assigns = %{type: :map}) do
    ~H"""
    <.live_component
      module={MapInput}
      id={input_id(@form, @field)}
      form={@form}
      field={@field}
      disabled={@disabled}
    />
    """
  end

  defp input(assigns = %{type: :string}) do
    ~H"""
    <textarea name={@form[@field].name} class="form-textarea">{@form[@field].value}</textarea>
    """
  end

  defp input(assigns = %{type: :boolean}) do
    ~H"""
    <div class="switch-container">
              <input type="radio" class="switch-left" name={@form[@field].name} id={@form[@field].id <> "_left"} checked={@form[@field].value == false} value="0">
              <input type="radio" class="switch-center"  name={@form[@field].name} id={@form[@field].id <> "_center"} checked={@form[@field].value in [nil, ""]} value="">
              <input type="radio" class="switch-right"  name={@form[@field].name} id={@form[@field].id <> "_right"} checked={@form[@field].value == true} value="1">

              <div class="switch">
                  <div class="switch-background">
                      <div class="bg-section left"></div>
                      <div class="bg-section center"></div>
                      <div class="bg-section right"></div>
                  </div>
                  <div class="switch-handle"></div>
                  <label for={@form[@field].id <> "_left"} class="label-area left"></label>
                  <label for={@form[@field].id <> "_center"} class="label-area center"></label>
                  <label for={@form[@field].id <> "_right"} class="label-area right"></label>
              </div>
          </div>
    """
  end

  defp input(assigns = %{type: :date}) do
    ~H"""
    <input type="date" class="form-input" name={@form[@field].name} value={@form[@field].value} />
    """
  end

  defp input(assigns = %{type: number}) when number in [:integer, :id, :float] do
    ~H"""
    <input type="number" class="form-input" name={@form[@field].name} value={@form[@field].value} />
    """
  end

  defp input(assigns = %{type: type}) when type in [:naive_datetime, :utc_datetime] do
    ~H"""
    <input type="datetime-local" class="form-input" name={@form[@field].name} value={@form[@field].value} />
    """
  end

  defp input(assigns = %{type: {_, {Ecto.Enum, %{mappings: mappings}}}}) do
    assigns = assign(assigns, :mappings, mappings)

    ~H"""
    <select name={@form[@field].name} class="form-select">
      <%= for {k, v} <- @mappings do %>
        <option value={k} selected={@form[@field].value == k}>{v}</option>
      <% end %>
    </select>
    """
  end

  defp input(assigns = %{type: {:array, {_, {Ecto.Enum, %{mappings: mappings}}}}}) do
    assigns = assign(assigns, :mappings, mappings)

    ~H"""
    <select name={@form[@field].name <> "[]"} class="form-select" multiple={true}>
      <%= for {k, v} <- @mappings do %>
        <option value={k} selected={Enum.member?(@form[@field].value || [], k)}>{v}</option>
      <% end %>
    </select>
    """
  end

  defp input(assigns) do
    ~H"""
    NO INPUT
    """
  end

  defp validate(resource, changeset, params, session, config) do
    resource
    |> Resource.change(changeset.data, params, config)
    |> Resource.validate(resource, session, config)
  end
end
