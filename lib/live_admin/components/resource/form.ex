defmodule LiveAdmin.Components.Container.Form do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import Phoenix.LiveView.Helpers
  import LiveAdmin.ErrorHelpers
  import LiveAdmin, only: [associated_resource: 3, get_config: 3, get_resource: 1]
  import LiveAdmin.Components.Container, only: [route_with_params: 2]

  alias __MODULE__.{ArrayInput, SearchSelect}
  alias LiveAdmin.{Resource, SessionStore}

  @supported_primitive_types [
    :string,
    :boolean,
    :date,
    :integer,
    :naive_datetime,
    :utc_datetime,
    :id,
    :binary_id,
    :float
  ]

  @impl true
  def update(assigns = %{record: record}, socket) do
    resource = get_resource(assigns)

    socket =
      socket
      |> assign(assigns)
      |> assign(:resource, resource)
      |> assign(:enabled, false)
      |> assign(:changeset, Resource.change(resource, record))

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    resource = get_resource(assigns)

    socket =
      socket
      |> assign(assigns)
      |> assign(:resource, resource)
      |> assign(:enabled, false)
      |> assign(:changeset, Resource.change(resource))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        let={f}
        for={@changeset}
        as="params"
        phx_change="validate"
        phx_submit={@action}
        phx_target={@myself}
        class="resource__form"
      >
        <%= for {field, type, opts} <- Resource.fields(@resource) do %>
          <.field
            field={field}
            type={type}
            form={f}
            immutable={Keyword.get(opts, :immutable, false)}
            resource={@resource}
            resources={@resources}
            form_ref={@myself}
            session={SessionStore.lookup(@session_id)}
          />
        <% end %>
        <div class="form__actions">
          <%= submit("Save",
            class: "resource__action#{if !@enabled, do: "--disabled", else: "--btn"}",
            disabled: !@enabled
          ) %>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event(
        "validate",
        %{"field" => field, "value" => value},
        socket = %{assigns: %{resource: resource, changeset: changeset, session_id: session_id}}
      ) do
    changeset =
      validate(
        resource,
        changeset,
        Map.put(changeset.changes, String.to_existing_atom(field), value),
        session_id
      )

    {:noreply,
     assign(socket,
       changeset: changeset,
       enabled: enabled?(changeset, socket.assigns.action, resource.config)
     )}
  end

  @impl true
  def handle_event(
        "validate",
        %{"params" => params},
        socket = %{assigns: %{resource: resource, changeset: changeset, session_id: session_id}}
      ) do
    changeset = validate(resource, changeset, params, session_id)

    {:noreply,
     assign(socket,
       changeset: changeset,
       enabled: enabled?(changeset, socket.assigns.action, resource.config)
     )}
  end

  @impl true
  def handle_event(
        "create",
        %{"params" => params},
        %{assigns: %{resource: resource, key: key, session_id: session_id}} = socket
      ) do
    socket =
      case Resource.create(resource, params, SessionStore.lookup(session_id)) do
        {:ok, _} -> push_redirect(socket, to: route_with_params(socket, [:list, key]))
        {:error, changeset} -> assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "update",
        %{"params" => params},
        %{assigns: %{resource: resource, key: key, session_id: session_id, record: record}} =
          socket
      ) do
    socket =
      case Resource.update(
             resource,
             record,
             params,
             SessionStore.lookup(session_id)
           ) do
        {:ok, _} -> push_redirect(socket, to: route_with_params(socket, [:list, key]))
        {:error, changeset} -> assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end

  defp field(assigns = %{type: type}) when type in @supported_primitive_types,
    do: field_group(assigns)

  defp field(assigns = %{type: {_, Ecto.Enum, _}}), do: field_group(assigns)

  defp field(assigns = %{type: {:array, :string}}), do: field_group(assigns)

  defp field(assigns = %{type: {:array, {_, Ecto.Enum, _}}}), do: field_group(assigns)

  defp field(assigns = %{type: {_, Ecto.Embedded, _}}) do
    ~H"""
    <div>
      <h2 class="embed__title"><%= @field %></h2>
      <div class="embed__group">
        <%= unless @immutable do %>
          <%= for fp <- inputs_for(@form, @field) do %>
            <%= for {field, type, _} <- fields_for_embed(@type) do %>
              <.field
                field={field}
                type={type}
                form={fp}
                immutable={false}
                resource={@resource}
                resources={@resources}
                form_ref={@form_ref}
                session={@session}
              />
            <% end %>
          <% end %>
        <% else %>
          <pre><%= @form |> input_value(@field) |> inspect() %></pre>
        <% end %>
      </div>
    </div>
    """
  end

  defp field(assigns) do
    ~H"""
    <div class="field__group--disabled">
      <%= label(@form, @field, class: "field__label") %>
      <%= textarea(@form, @field, disabled: true, value: @form |> input_value(@field) |> inspect()) %>
    </div>
    """
  end

  defp field_group(assigns) do
    ~H"""
    <div class={"field__group#{if @immutable, do: "--disabled"}"}>
      <%= label(@form, @field, class: "field__label") %>
      <.input
        form={@form}
        type={@type}
        field={@field}
        disabled={@immutable}
        resource={@resource}
        resources={@resources}
        form_ref={@form_ref}
        session={@session}
      />
      <%= error_tag(@form, @field) %>
    </div>
    """
  end

  defp input(assigns = %{type: id}) when id in [:id, :binary_id] do
    assigns.resource.schema
    |> associated_resource(assigns.field, assigns.resources)
    |> case do
      nil ->
        ~H"""
        <%= textarea(@form, @field, rows: 1, class: "field__text", disabled: @disabled) %>
        """

      resource ->
        ~H"""
        <%= unless @form.data |> Ecto.primary_key() |> Keyword.keys() |> Enum.member?(@field) do %>
          <.live_component
            module={SearchSelect}
            id={assigns.field}
            form={@form}
            field={@field}
            disabled={@disabled}
            resource={resource}
            form_ref={@form_ref}
            session={@session}
            handle_select="validate"
          />
        <% else %>
          <div class="form__number">
            <%= number_input(@form, @field, class: "field__number", disabled: @disabled) %>
          </div>
        <% end %>
        """
    end
  end

  defp input(assigns = %{type: {:array, :string}}) do
    ~H"""
    <.live_component
      module={ArrayInput}
      id={assigns.field}
      form={@form}
      field={@field}
      disabled={@disabled}
      form_ref={@form_ref}
    />
    """
  end

  defp input(assigns = %{type: :string}) do
    ~H"""
    <%= textarea(@form, @field, rows: 1, class: "field__text", disabled: @disabled) %>
    """
  end

  defp input(assigns = %{type: :boolean}) do
    ~H"""
    <div class="form__checkbox">
      <%= checkbox(@form, @field, class: "field__checkbox", disabled: @disabled) %>
    </div>
    """
  end

  defp input(assigns = %{type: :date}) do
    ~H"""
    <%= date_input(@form, @field, class: "field__date", disabled: @disabled) %>
    """
  end

  defp input(assigns = %{type: number}) when number in [:integer, :id] do
    ~H"""
    <div class="form__number">
      <%= number_input(@form, @field, class: "field__number", disabled: @disabled) %>
    </div>
    """
  end

  defp input(assigns = %{type: :float}) do
    ~H"""
    <div class="form__number">
      <%= number_input(@form, @field, class: "field__number", disabled: @disabled, step: "any") %>
    </div>
    """
  end

  defp input(assigns = %{type: type}) when type in [:naive_datetime, :utc_datetime] do
    ~H"""
    <div class="form__time">
      <%= datetime_local_input(@form, @field, class: "field__time", disabled: @disabled) %>
    </div>
    """
  end

  defp input(assigns = %{type: {_, Ecto.Enum, %{mappings: mappings}}}) do
    ~H"""
    <%= select(@form, @field, [nil | Keyword.keys(mappings)],
      disabled: @disabled,
      class: "field__select"
    ) %>
    """
  end

  defp input(assigns = %{type: {:array, {_, Ecto.Enum, %{mappings: mappings}}}}) do
    ~H"""
    <div class="field__checkbox--group">
      <%= hidden_input(@form, @field, name: input_name(@form, @field) <> "[]", value: nil) %>
      <%= for option <- Keyword.keys(mappings) do %>
        <%= checkbox(@form, @field,
          name: input_name(@form, @field) <> "[]",
          checked_value: option,
          value: @form |> input_value(@field) |> Kernel.||([]) |> Enum.find(&(&1 == option)),
          unchecked_value: "",
          hidden_input: false,
          disabled: @disabled,
          id: input_id(@form, @field) <> to_string(option)
        ) %>
        <label for={input_id(@form, @field) <> to_string(option)}>
          <%= option %>
        </label>
      <% end %>
    </div>
    """
  end

  defp fields_for_embed({_, _, %{related: schema}}), do: Resource.fields(schema, %{})

  defp validate(resource, changeset, params, session_id) do
    resource
    |> Resource.change(changeset.data, params)
    |> Resource.validate(resource.config, SessionStore.lookup(session_id))
  end

  def enabled?(changeset, action, config) do
    get_config(config, :"#{action}_with", true) && Enum.empty?(changeset.errors)
  end
end
