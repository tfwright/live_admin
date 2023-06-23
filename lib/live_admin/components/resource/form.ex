defmodule LiveAdmin.Components.Container.Form do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin.ErrorHelpers
  import LiveAdmin, only: [associated_resource: 3, get_config: 3, route_with_params: 2]

  alias __MODULE__.{ArrayInput, MapInput, SearchSelect}
  alias LiveAdmin.Resource

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
    socket =
      socket
      |> assign(assigns)
      |> assign(:enabled, false)
      |> assign(:changeset, Resource.change(assigns.resource, record))

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:enabled, false)
      |> assign(:changeset, Resource.change(assigns.resource))

    {:ok, socket}
  end

  @impl true
  def render(assigns = %{record: nil}) do
    ~H"""
    <div>No record found</div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="form-page" phx-hook="FormPage">
      <.form
        :let={f}
        for={@changeset}
        as={:params}
        phx-change="validate"
        phx-submit={@action}
        phx-target={@myself}
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
            session={@session}
            prefix={@prefix}
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
  def handle_event("after_create", _, socket) do
    {:noreply, push_patch(socket, to: route_with_params(socket, socket.assigns.key))}
  end

  @impl true
  def handle_event(
        "validate",
        %{"field" => field, "value" => value},
        socket = %{assigns: %{resource: resource, changeset: changeset, session: session}}
      ) do
    changeset = validate(resource, changeset, Map.put(changeset.params, field, value), session)

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
        socket = %{assigns: %{resource: resource, changeset: changeset, session: session}}
      ) do
    changeset = validate(resource, changeset, params, session)

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
        %{assigns: %{resource: resource, session: session}} = socket
      ) do
    socket =
      case Resource.create(resource, params, session) do
        {:ok, _} -> push_event(socket, "create", %{})
        {:error, changeset} -> assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "update",
        %{"params" => params},
        %{assigns: %{resource: resource, session: session, record: record}} = socket
      ) do
    socket =
      Resource.update(resource, record, params, session)
      |> case do
        {:ok, _} ->
          socket
          |> push_event("success", %{msg: "Changes successfully saved"})
          |> assign(:enabled, false)

        {:error, changeset} ->
          assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end

  def handle_event("add_embed", %{"field" => field}, socket = %{assigns: %{changeset: changeset}}) do
    field_name = String.to_existing_atom(field)

    socket =
      update(socket, :changeset, fn changeset ->
        existing =
          Ecto.Changeset.get_change(changeset, field_name) ||
            Ecto.Changeset.get_field(changeset, field_name)

        new_value =
          socket.assigns.resource.schema.__schema__(:embed, field_name).cardinality
          |> case do
            :many -> (existing || []) ++ [%{}]
            :one -> %{}
          end

        Ecto.Changeset.put_embed(changeset, field_name, new_value)
      end)

    {:noreply,
     assign(
       socket,
       :enabled,
       enabled?(changeset, socket.assigns.action, socket.assigns.resource.config)
     )}
  end

  def handle_event(
        "remove_embed",
        %{"field" => field, "idx" => idx},
        socket = %{assigns: %{changeset: changeset}}
      ) do
    field_name = String.to_existing_atom(field)
    index = String.to_integer(idx)

    socket =
      update(socket, :changeset, fn changeset ->
        existing =
          (Ecto.Changeset.get_change(changeset, field_name) ||
             Ecto.Changeset.get_field(changeset, field_name, []))
          |> Enum.filter(fn
            %{action: action} when action != :insert -> false
            _ -> true
          end)

        Ecto.Changeset.put_embed(changeset, field_name, List.delete_at(existing, index))
      end)

    {:noreply,
     assign(
       socket,
       :enabled,
       enabled?(changeset, socket.assigns.action, socket.assigns.resource.config)
     )}
  end

  def handle_event(
        "remove_embed",
        %{"field" => field},
        socket = %{assigns: %{changeset: changeset}}
      ) do
    field_name = String.to_existing_atom(field)

    socket =
      update(socket, :changeset, fn changeset ->
        Ecto.Changeset.put_embed(changeset, field_name, nil)
      end)

    {:noreply,
     assign(
       socket,
       :enabled,
       enabled?(changeset, socket.assigns.action, socket.assigns.resource.config)
     )}
  end

  defp field(assigns = %{type: type}) when type in @supported_primitive_types,
    do: field_group(assigns)

  defp field(assigns = %{type: {_, Ecto.Enum, _}}), do: field_group(assigns)

  defp field(assigns = %{type: {:array, :string}}), do: field_group(assigns)

  defp field(assigns = %{type: :map}), do: field_group(assigns)

  defp field(assigns = %{type: {:array, {_, Ecto.Enum, _}}}), do: field_group(assigns)

  defp field(assigns = %{type: {_, Ecto.Embedded, meta}}) do
    assigns = assign(assigns, :meta, meta)

    ~H"""
    <div>
      <h2 class="embed__title"><%= humanize(@field) %></h2>
      <div class="embed__group">
        <%= unless @immutable do %>
          <%= hidden_input(@form, @field, value: "delete") %>
          <%= unless input_value(@form, @field) == nil do %>
            <%= for fp <- inputs_for(@form, @field) do %>
              <div class="embed__item">
                <div>
                  <a
                    class="button__remove"
                    phx-click="remove_embed"
                    phx-value-field={@field}
                    phx-value-idx={fp.index}
                    phx-target={@form_ref}
                  />
                </div>
                <div>
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
                      prefix={@prefix}
                    />
                  <% end %>
                </div>
              </div>
            <% end %>
          <% end %>
          <%= if @meta.cardinality == :many || input_value(@form, @field) == nil do %>
            <div class="form__actions">
              <a
                href="#"
                phx-click="add_embed"
                phx-value-field={@field}
                phx-target={@form_ref}
                class="resource__action--btn"
              >
                New
              </a>
            </div>
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
      <%= textarea(@form, @field,
        rows: 1,
        disabled: true,
        value: @form |> input_value(@field) |> inspect()
      ) %>
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
        prefix={@prefix}
      />
      <%= error_tag(@form, @field) %>
    </div>
    """
  end

  defp input(assigns = %{type: id}) when id in [:id, :binary_id] do
    assigns =
      assign(
        assigns,
        :associated_resource,
        associated_resource(assigns.resource.schema, assigns.field, assigns.resources)
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
          form_ref={@form_ref}
          session={@session}
          handle_select="validate"
          prefix={@prefix}
        />
      <% else %>
        <div class="form__number">
          <%= number_input(@form, @field, class: "field__number", disabled: @disabled) %>
        </div>
      <% end %>
    <% else %>
      <%= textarea(@form, @field, rows: 1, class: "field__text", disabled: @disabled) %>
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
      form_ref={@form_ref}
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
    assigns = assign(assigns, :mappings, mappings)

    ~H"""
    <%= select(@form, @field, [nil | Keyword.keys(@mappings)],
      disabled: @disabled,
      class: "field__select"
    ) %>
    """
  end

  defp input(assigns = %{type: {:array, {_, Ecto.Enum, %{mappings: mappings}}}}) do
    assigns = assign(assigns, :mappings, mappings)

    ~H"""
    <div class="field__checkbox--group">
      <%= hidden_input(@form, @field, name: input_name(@form, @field) <> "[]", value: nil) %>
      <%= for option <- Keyword.keys(@mappings) do %>
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

  defp validate(resource, changeset, params, session) do
    resource
    |> Resource.change(changeset.data, params)
    |> Resource.validate(resource.config, session)
  end

  def enabled?(changeset, action, config) do
    get_config(config, :"#{action}_with", true) && Enum.empty?(changeset.errors)
  end
end
