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
          <span>{record_label(@record, @resource, @config)}</span>
        </h1>
        <div class="contextual-actions">
          <.link navigate={route_with_params(assigns, segments: [@record])} class="btn btn-secondary">
            {trans("Back")}
          </.link>
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
          <div class="edit-view">
            <form class="form-grid" onsubmit="saveEdit(event)">
              <div class="form-field">
                <label class="form-label" for="edit-task-name">Task Name</label>
                <input type="text" id="edit-task-name" class="form-input" value="Database schema" />
              </div>
              <div class="form-field">
                <label class="form-label" for="edit-status">Status</label>
                <select id="edit-status" class="form-select">
                  <option value="completed" selected>Completed</option>
                  <option value="active">Active</option>
                  <option value="pending">Pending</option>
                </select>
              </div>
              <div class="form-field">
                <label class="form-label" for="edit-created">Created</label>
                <input type="date" id="edit-created" class="form-input" value="2025-09-15" />
              </div>
              <div class="form-field">
                <label class="form-label" for="edit-updated">Updated</label>
                <input type="date" id="edit-updated" class="form-input" value="2025-10-03" />
              </div>
              <div class="form-field">
                <label class="form-label" for="edit-assignee">Assignee</label>
                <input type="text" id="edit-assignee" class="form-input" value="Emily Rodriguez" />
              </div>

              <div class="form-subsection">
                <h4 class="form-subsection-title">Contact Information</h4>
                <div class="form-subgrid">
                  <div class="form-field">
                    <label class="form-label" for="edit-contact-email">Email</label>
                    <input
                      type="email"
                      id="edit-contact-email"
                      class="form-input"
                      value="emily.rodriguez@example.com"
                    />
                  </div>
                  <div class="form-field">
                    <label class="form-label" for="edit-contact-phone">Phone</label>
                    <input
                      type="tel"
                      id="edit-contact-phone"
                      class="form-input"
                      value="+1 (555) 123-4567"
                    />
                  </div>
                  <div class="form-field">
                    <label class="form-label" for="edit-contact-extension">Extension</label>
                    <input type="text" id="edit-contact-extension" class="form-input" value="4521" />
                  </div>
                  <div class="form-field">
                    <label class="form-label" for="edit-contact-department">Department Contact</label>
                    <input
                      type="text"
                      id="edit-contact-department"
                      class="form-input"
                      value="Engineering Team Lead"
                    />
                  </div>
                </div>
              </div>

              <div class="form-field">
                <label class="form-label" for="edit-due-date">Due Date</label>
                <input type="date" id="edit-due-date" class="form-input" value="2025-10-03" />
              </div>
              <div class="form-field">
                <label class="form-label" for="edit-progress">Progress</label>
                <input
                  type="number"
                  id="edit-progress"
                  class="form-input"
                  value="100"
                  min="0"
                  max="100"
                />
              </div>
              <div class="form-field">
                <label class="form-label" for="edit-priority">Priority</label>
                <select id="edit-priority" class="form-select">
                  <option value="low">Low</option>
                  <option value="medium">Medium</option>
                  <option value="high" selected>High</option>
                </select>
              </div>
              <div class="form-field">
                <label class="form-label" for="edit-department">Department</label>
                <input type="text" id="edit-department" class="form-input" value="Engineering" />
              </div>
              <div class="form-field">
                <label class="form-label" for="edit-budget">Budget</label>
                <input type="text" id="edit-budget" class="form-input" value="$45,000" />
              </div>
              <div class="form-field">
                <label class="form-label" for="edit-hours">Hours</label>
                <input type="number" id="edit-hours" class="form-input" value="120" />
              </div>
              <div class="form-field">
                <label class="form-label" for="edit-category">Category</label>
                <input type="text" id="edit-category" class="form-input" value="Backend" />
              </div>
              <div class="form-field">
                <label class="form-label" for="edit-tags">Tags</label>
                <input type="text" id="edit-tags" class="form-input" value="SQL, Schema" />
              </div>
              <div class="form-field">
                <label class="form-label" for="edit-version">Version</label>
                <input type="text" id="edit-version" class="form-input" value="2.1" />
              </div>
            </form>

            <div class="detail-section">
              <div class="form-field">
                <label class="form-label" for="edit-description">Description</label>
                <textarea id="edit-description" class="form-textarea">This task involves designing and implementing the complete database schema for Project Alpha. The schema has been optimized for performance and scalability, incorporating best practices for data normalization and indexing strategies.</textarea>
              </div>
            </div>

            <div class="detail-section">
              <div class="form-field">
                <label class="form-label" for="edit-notes">Notes</label>
                <textarea id="edit-notes" class="form-textarea">Schema optimized - All tables have been reviewed and optimized. Foreign key relationships established. Indexes created for frequently queried columns. Migration scripts prepared for deployment.</textarea>
              </div>
            </div>

            <div class="form-actions">
              <button type="button" class="btn btn-secondary" onclick="cancelEdit()">Cancel</button>
              <button type="button" class="btn btn-primary" onclick="saveEdit(event)">
                Save Changes
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

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

  def field(assigns) do
    ~H"""
    <div class={"field__group#{if @immutable, do: "--disabled"} field__#{field_class(@type)}"}>
      {label(@form, @field, @field |> humanize() |> trans(), class: "field__label")}
      <%= if supported_type?(@type) do %>
        <.input
          form={@form}
          type={@type}
          field={@field}
          disabled={@immutable}
          resource={@resource}
          resources={@resources}
          session={@session}
          prefix={@prefix}
          repo={@repo}
          config={@config}
        />
      <% else %>
        {textarea(@form, @field,
          rows: 1,
          disabled: true,
          value: @form |> input_value(@field) |> inspect()
        )}
      <% end %>
      {error_tag(@form, @field)}
    </div>
    """
  end

  defp input(assigns = %{type: {_, {Ecto.Embedded, _}}}) do
    ~H"""
    <.embed
      id={input_id(@form, @field)}
      type={@type}
      disabled={@disabled}
      form={@form}
      field={@field}
      resource={@resource}
      resources={@resource}
      session={@session}
      prefix={@prefix}
      repo={@repo}
      config={@config}
    />
    """
  end

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
      <%= unless @form.data |> Ecto.primary_key() |> Keyword.keys() |> Enum.member?(@field) do %>
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
        <div class="form__number">
          {number_input(@form, @field, disabled: @disabled)}
        </div>
      <% end %>
    <% else %>
      {textarea(@form, @field, rows: 1, disabled: @disabled)}
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
    {textarea(@form, @field, rows: 1, disabled: @disabled, phx_debounce: 200)}
    """
  end

  defp input(assigns = %{type: :boolean}) do
    ~H"""
    <div class="form__checkbox">
      <%= for option <- ["true", "false"] do %>
        {radio_button(@form, @field, option)}
        {trans(option)}
      <% end %>
      {radio_button(@form, @field, "", checked: input_value(@form, @field) in ["", nil])}
      {trans("nil")}
    </div>
    """
  end

  defp input(assigns = %{type: :date}) do
    ~H"""
    {date_input(@form, @field, disabled: @disabled)}
    """
  end

  defp input(assigns = %{type: number}) when number in [:integer, :id] do
    ~H"""
    <div class="form__number">
      {number_input(@form, @field, disabled: @disabled, phx_debounce: 200)}
    </div>
    """
  end

  defp input(assigns = %{type: :float}) do
    ~H"""
    <div class="form__number">
      {number_input(@form, @field, disabled: @disabled, step: "any", phx_debounce: 200)}
    </div>
    """
  end

  defp input(assigns = %{type: type}) when type in [:naive_datetime, :utc_datetime] do
    ~H"""
    <div class="form__time">
      {datetime_local_input(@form, @field, disabled: @disabled)}
    </div>
    """
  end

  defp input(assigns = %{type: {_, {Ecto.Enum, %{mappings: mappings}}}}) do
    assigns = assign(assigns, :mappings, mappings)

    ~H"""
    {select(@form, @field, [nil | Keyword.keys(@mappings)], disabled: @disabled)}
    """
  end

  defp input(assigns = %{type: {:array, {_, {Ecto.Enum, %{mappings: mappings}}}}}) do
    assigns = assign(assigns, :mappings, mappings)

    ~H"""
    <div class="checkbox__group">
      {hidden_input(@form, @field, name: input_name(@form, @field) <> "[]", value: nil)}
      <%= for option <- Keyword.keys(@mappings) do %>
        {checkbox(@form, @field,
          name: input_name(@form, @field) <> "[]",
          checked_value: option,
          value:
            @form
            |> input_value(@field)
            |> Kernel.||([])
            |> Enum.find(&(to_string(&1) == to_string(option))),
          unchecked_value: "",
          hidden_input: false,
          disabled: @disabled,
          id: input_id(@form, @field) <> to_string(option)
        )}
        <label for={input_id(@form, @field) <> to_string(option)}>
          {trans(to_string(option))}
        </label>
      <% end %>
    </div>
    """
  end

  defp validate(resource, changeset, params, session, config) do
    resource
    |> Resource.change(changeset.data, params, config)
    |> Resource.validate(resource, session, config)
  end
end
