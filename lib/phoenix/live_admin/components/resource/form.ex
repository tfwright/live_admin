defmodule Phoenix.LiveAdmin.Components.Resource.Form do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import Phoenix.LiveAdmin.ErrorHelpers
  import Phoenix.LiveAdmin.Components.Resource, only: [repo: 0, fields: 2, route_with_params: 2]
  import Phoenix.LiveAdmin, only: [get_config: 2]

  alias Ecto.Changeset
  alias Phoenix.LiveAdmin.SessionStore

  @supported_field_types [
    :string,
    :boolean,
    :date,
    :integer,
    :naive_datetime,
    :utc_datetime,
    :id
  ]

  @impl true
  def update(assigns = %{record: record, config: config}, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:changeset, changeset(record, config))

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    {mod, func, args} =
      get_in(assigns, [:config, :components, :new]) || {__MODULE__, :default_render, []}

    ~H"""
    <div>
      <%= apply(mod, func, [args ++ assigns]) %>
    </div>
    """
  end

  def default_render(assigns) do
    ~H"""
    <%= form_for @changeset , "#", [as: "params", phx_change: "validate", phx_submit: @action, phx_target: @myself, class: "resource__form"], fn f -> %>
      <%= for {field, type, opts} <- fields(@resource, @config) do %>
        <.field field={field} type={type} form={f} immutable={Keyword.get(opts, :immutable, false)} />
      <% end %>
      <div class="form__actions">
        <%= submit "Save", class: "form__save" %>
      </div>
    <% end %>
    """
  end

  @impl true
  def handle_event(
        "validate",
        %{"params" => params},
        %{assigns: %{changeset: changeset, config: config, session_id: session_id}} = socket
      ) do
    changeset =
      changeset.data
      |> changeset(config, params)
      |> validate_resource(config, SessionStore.lookup(session_id))
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
      case create_resource(resource, config, params, SessionStore.lookup(session_id)) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Created #{resource}")
          |> push_redirect(to: route_with_params(socket, [:list, key]))

        {:error, _} ->
          put_flash(socket, :error, "Could not create #{resource}")
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
      case update_resource(
             record,
             config,
             params,
             SessionStore.lookup(session_id)
           ) do
        {:ok, _} ->
          socket
          |> put_flash(:info, "Updated #{resource}")
          |> push_redirect(to: route_with_params(socket, [:list, key]))

        {:error, _} ->
          put_flash(socket, :error, "Could not update #{resource}")
      end

    {:noreply, socket}
  end

  defp field(assigns = %{type: type}) when type in @supported_field_types,
    do: field_group(assigns)

  defp field(assigns = %{type: {_, Ecto.Enum, _}}), do: field_group(assigns)

  defp field(assigns = %{type: {_, Ecto.Embedded, _}}) do
    ~H"""
    <div>
      <h2 class="embed__title"><%= @field %></h2>
      <div class="embed__group">
        <%= unless @immutable do %>
          <%= inputs_for @form, @field, fn fp -> %>
            <%= for {field, type, _} <- fields_for_embed(@type) do %>
              <.field field={field} type={type} form={fp} immutable={false} />
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
      <.input form={@form} type={@type} field={@field} disabled={@immutable} />
      <%= error_tag @form, @field %>
    </div>
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

  defp fields_for_embed({_, _, %{related: schema}}), do: fields(schema, %{})

  defp changeset(record, config, params \\ %{})

  defp changeset(record, config, params) when is_struct(record) do
    change_resource(record, config, params)
  end

  defp changeset(resource, config, params) do
    resource
    |> struct(%{})
    |> change_resource(config, params)
  end

  defp change_resource(record = %resource{}, config, params) do
    fields = fields(resource, config)

    {primitives, embeds} =
      Enum.split_with(fields, fn
        {_, {_, Ecto.Embedded, _}, _} -> false
        _ -> true
      end)

    castable_fields =
      Enum.flat_map(primitives, fn {field, _, opts} ->
        if Keyword.get(opts, :immutable, false), do: [], else: [field]
      end)

    changeset = Changeset.cast(record, params, castable_fields)

    Enum.reduce(embeds, changeset, fn {field, {_, Ecto.Embedded, _}, _}, changeset ->
      Changeset.cast_embed(changeset, field,
        with: fn embed, params ->
          change_resource(embed, %{}, params)
        end
      )
    end)
  end

  defp create_resource(resource, config, params, session) do
    config
    |> get_config(:create_with)
    |> case do
      nil ->
        resource
        |> changeset(config, params)
        |> repo().insert(prefix: session[:__prefix__])

      {mod, func_name, args} ->
        apply(mod, func_name, [params, session] ++ args)
    end
  end

  defp update_resource(record, config, params, session) do
    config
    |> get_config(:update_with)
    |> case do
      nil ->
        record
        |> changeset(config, params)
        |> repo().update()

      {mod, func_name, args} ->
        apply(mod, func_name, [params, session] ++ args)
    end
  end

  defp validate_resource(changeset, config, session) do
    config
    |> get_config(:validate_with)
    |> case do
      nil -> changeset
      {mod, func_name, args} -> apply(mod, func_name, [changeset, session] ++ args)
    end
  end
end
