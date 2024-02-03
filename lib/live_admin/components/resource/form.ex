defmodule LiveAdmin.Components.Container.Form do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  use PhoenixHTMLHelpers

  import LiveAdmin.Components
  import LiveAdmin.ErrorHelpers
  import LiveAdmin, only: [associated_resource: 4, route_with_params: 2, trans: 1]
  import LiveAdmin.View, only: [supported_type?: 1, field_class: 1]

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
    <div><%= trans("No record found") %></div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="form-page" class="view__container">
      <.form
        :let={f}
        for={@changeset}
        as={:params}
        phx-change="validate"
        phx-submit={@action}
        phx-target={@myself}
        class="resource__form"
      >
        <%= for {field, type, opts} <- Resource.fields(@resource, @config) do %>
          <.field
            field={field}
            type={type}
            form={f}
            immutable={Keyword.get(opts, :immutable, false)}
            resource={@resource}
            resources={@resources}
            session={@session}
            prefix={@prefix}
            repo={@repo}
            config={@config}
          />
        <% end %>
        <div class="form__actions">
          <%= if assigns[:record] do %>
            <a
              href={route_with_params(assigns, segments: [@record])}
              class="resource__action--secondary"
            >
              <%= trans("Cancel") %>
            </a>
          <% end %>
          <%= submit(trans("Save"),
            class:
              "resource__action#{if Enum.any?(@changeset.errors) || Enum.empty?(@changeset.changes), do: "--disabled", else: "--btn"}",
            disabled: Enum.any?(@changeset.errors) || Enum.empty?(@changeset.changes)
          ) %>
        </div>
      </.form>
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
          |> push_redirect(
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
          |> push_redirect(to: route_with_params(socket.assigns, segments: [record]))

        {:error, changeset} ->
          assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end

  def field(assigns) do
    ~H"""
    <div class={"field__group#{if @immutable, do: "--disabled"} field__#{field_class(@type)}"}>
      <%= label(@form, @field, @field |> humanize() |> trans(), class: "field__label") %>
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
        <%= textarea(@form, @field,
          rows: 1,
          disabled: true,
          value: @form |> input_value(@field) |> inspect()
        ) %>
      <% end %>
      <%= error_tag(@form, @field) %>
    </div>
    """
  end

  defp input(assigns = %{type: {_, Ecto.Embedded, _}}) do
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
          <%= number_input(@form, @field, disabled: @disabled) %>
        </div>
      <% end %>
    <% else %>
      <%= textarea(@form, @field, rows: 1, disabled: @disabled) %>
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
    <%= textarea(@form, @field, rows: 1, disabled: @disabled, phx_debounce: 200) %>
    """
  end

  defp input(assigns = %{type: :boolean}) do
    ~H"""
    <div class="form__checkbox">
      <%= for option <- ["true", "false"] do %>
        <%= radio_button(@form, @field, option) %>
        <%= trans(option) %>
      <% end %>
      <%= radio_button(@form, @field, "", checked: input_value(@form, @field) in ["", nil]) %>
      <%= trans("nil") %>
    </div>
    """
  end

  defp input(assigns = %{type: :date}) do
    ~H"""
    <%= date_input(@form, @field, disabled: @disabled) %>
    """
  end

  defp input(assigns = %{type: number}) when number in [:integer, :id] do
    ~H"""
    <div class="form__number">
      <%= number_input(@form, @field, disabled: @disabled, phx_debounce: 200) %>
    </div>
    """
  end

  defp input(assigns = %{type: :float}) do
    ~H"""
    <div class="form__number">
      <%= number_input(@form, @field, disabled: @disabled, step: "any", phx_debounce: 200) %>
    </div>
    """
  end

  defp input(assigns = %{type: type}) when type in [:naive_datetime, :utc_datetime] do
    ~H"""
    <div class="form__time">
      <%= datetime_local_input(@form, @field, disabled: @disabled) %>
    </div>
    """
  end

  defp input(assigns = %{type: {_, Ecto.Enum, %{mappings: mappings}}}) do
    assigns = assign(assigns, :mappings, mappings)

    ~H"""
    <%= select(@form, @field, [nil | Keyword.keys(@mappings)], disabled: @disabled) %>
    """
  end

  defp input(assigns = %{type: {:array, {_, Ecto.Enum, %{mappings: mappings}}}}) do
    assigns = assign(assigns, :mappings, mappings)

    ~H"""
    <div class="checkbox__group">
      <%= hidden_input(@form, @field, name: input_name(@form, @field) <> "[]", value: nil) %>
      <%= for option <- Keyword.keys(@mappings) do %>
        <%= checkbox(@form, @field,
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
        ) %>
        <label for={input_id(@form, @field) <> to_string(option)}>
          <%= trans(to_string(option)) %>
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
