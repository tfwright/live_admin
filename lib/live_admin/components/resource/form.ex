defmodule LiveAdmin.Components.Container.Form do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import Phoenix.LiveView.Helpers
  import LiveAdmin.ErrorHelpers
  import LiveAdmin, only: [associated_resource: 3, get_config: 3]
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
    :id
  ]

  @impl true
  def update(assigns = %{record: record, config: config, action: action}, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:enabled, get_config(config, :"#{action}_with", true))
      |> assign(:changeset, Resource.change(record, config))

    {:ok, socket}
  end

  @impl true
  def update(assigns = %{config: config, action: action}, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:enabled, get_config(config, :"#{action}_with", true))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    {mod, func, args} =
      get_in(assigns, [:config, :components, :new]) || {__MODULE__, :default_render, []}

    assigns = assign(assigns, form_ref: assigns.myself)

    ~H"""
    <div>
      <%= apply(mod, func, args ++ [SessionStore.lookup(@session_id), assigns]) %>
    </div>
    """
  end

  def default_render(session, assigns) do
    ~H"""
    <.form let={f} for={@changeset} as={"params"} phx_change="validate" phx_submit={@action} phx_target={@myself} class="resource__form">
      <%= for {field, type, opts} <- Resource.fields(@resource, @config) do %>
        <.field
          field={field}
          type={type}
          form={f}
          immutable={Keyword.get(opts, :immutable, false)}
          resource={@resource}
          resources={@resources}
          form_ref={@form_ref}
          session={session}
        />
      <% end %>
      <div class="form__actions">
        <%= submit "Save", class: "resource__action#{if !@enabled, do: "--disabled", else: "--btn"}", disabled: !@enabled %>
      </div>
    </.form>
    """
  end

  @impl true
  def handle_event(
        "put_change",
        params = %{"field" => field},
        socket = %{assigns: %{changeset: changeset}}
      ) do
    changeset = Resource.put_change(changeset, String.to_existing_atom(field), params["value"])

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event(
        "validate",
        %{"params" => params},
        %{assigns: %{changeset: changeset, config: config, session_id: session_id}} = socket
      ) do
    changeset =
      changeset.data
      |> Resource.change(config, params)
      |> Resource.validate(config, SessionStore.lookup(session_id))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event(
        "create",
        %{"params" => params},
        %{assigns: %{resource: resource, key: key, config: config, session_id: session_id}} =
          socket
      ) do
    socket =
      case Resource.create(resource, config, params, SessionStore.lookup(session_id)) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Created #{resource}")
          |> push_redirect(to: route_with_params(socket, [:list, key]))

        {:error, changeset} ->
          assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "update",
        %{"params" => params},
        %{
          assigns: %{
            resource: resource,
            key: key,
            config: config,
            session_id: session_id,
            record: record
          }
        } = socket
      ) do
    socket =
      case Resource.update(
             record,
             config,
             params,
             SessionStore.lookup(session_id)
           ) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Updated #{resource}")
          |> push_redirect(to: route_with_params(socket, [:list, key]))

        {:error, changeset} ->
          assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end

  defp field(assigns = %{type: type}) when type in @supported_primitive_types,
    do: field_group(assigns)

  defp field(assigns = %{type: {_, Ecto.Enum, _}}), do: field_group(assigns)

  defp field(assigns = %{type: {:array, :string}}), do: field_group(assigns)

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
    <div class={"field__group--disabled"}>
      <%= label @form, @field, class: "field__label" %>
      <%= textarea @form, @field, disabled: true, value: @form |> input_value(@field) |> inspect() %>
    </div>
    """
  end

  defp field_group(assigns) do
    ~H"""
    <div class={"field__group#{if @immutable, do: "--disabled"}"}>
      <%= label @form, @field, class: "field__label" %>
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
      <%= error_tag @form, @field %>
    </div>
    """
  end

  defp input(assigns = %{type: :id}) do
    assigns.resource
    |> associated_resource(assigns.field, assigns.resources)
    |> case do
      nil ->
        ~H"""
        <%= textarea @form, @field, rows: 1, class: "field__text", disabled: @disabled %>
        """

      {_, {resource, config}} ->
        ~H"""
        <%= unless @form.data |> Ecto.primary_key() |> Keyword.keys() |> Enum.member?(@field) do %>
          <.live_component
            module={SearchSelect}
            id={assigns.field}
            form={@form}
            field={@field}
            disabled={@disabled}
            resource={resource}
            config={config}
            form_ref={@form_ref}
            session={@session}
          />
        <% else %>
          <div class="form__number">
            <%= number_input @form, @field, class: "field__number", disabled: @disabled %>
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
    <%= textarea @form, @field, rows: 1, class: "field__text", disabled: @disabled %>
    """
  end

  defp input(assigns = %{type: :boolean}) do
    ~H"""
    <div class="form__checkbox">
      <%= checkbox @form, @field, class: "field__checkbox", disabled: @disabled %>
    </div>
    """
  end

  defp input(assigns = %{type: :date}) do
    ~H"""
    <%= date_input @form, @field, class: "field__date", disabled: @disabled %>
    """
  end

  defp input(assigns = %{type: number}) when number in [:integer, :id] do
    ~H"""
    <div class="form__number">
      <%= number_input @form, @field, class: "field__number", disabled: @disabled %>
    </div>
    """
  end

  defp input(assigns = %{type: type}) when type in [:naive_datetime, :utc_datetime] do
    ~H"""
    <div class="form__time">
      <%= datetime_local_input @form, @field, class: "field__time", disabled: @disabled %>
    </div>
    """
  end

  defp input(assigns = %{type: {_, Ecto.Enum, %{mappings: mappings}}}) do
    ~H"""
    <%= select @form, @field, mappings, disabled: @disabled, class: "field__select" %>
    """
  end

  defp fields_for_embed({_, _, %{related: schema}}), do: Resource.fields(schema, %{})
end
