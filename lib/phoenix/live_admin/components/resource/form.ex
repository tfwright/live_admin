defmodule Phoenix.LiveAdmin.Components.Resource.Form do
  use Phoenix.Component
  use Phoenix.HTML

  import Phoenix.LiveAdmin.ErrorHelpers
  import Phoenix.LiveAdmin.Components.Resource, only: [fields: 2]

  @supported_field_types [
    :string,
    :boolean,
    :date,
    :integer,
    :naive_datetime,
    :utc_datetime,
    :id
  ]

  def render(assigns) do
    ~H"""
    <%= form_for @changeset , "#", [as: "params", phx_change: "validate", phx_submit: @action, class: "resource__form"], fn f -> %>
      <%= for {field, type, opts} <- fields(@resource, @config) do %>
        <.field field={field} type={type} form={f} immutable={Keyword.get(opts, :immutable, false)} />
      <% end %>
      <div class="form__actions">
        <%= submit "Save", class: "form__save" %>
      </div>
    <% end %>
    """
  end

  def field(assigns = %{type: type}) when type in @supported_field_types, do: field_group(assigns)

  def field(assigns = %{type: {_, Ecto.Enum, _}}), do: field_group(assigns)

  def field(assigns = %{type: {_, Ecto.Embedded, _}}) do
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

  def field(assigns) do
    ~H"""
    <div class={"field__group--disabled"}>
      <%= label @form, @field, class: "field__label" %>
      <%= textarea @form, @field, disabled: true, value: @form |> input_value(@field) |> inspect() %>
    </div>
    """
  end

  def field_group(assigns) do
    ~H"""
    <div class={"field__group#{if @immutable, do: "--disabled"}"}>
      <%= label @form, @field, class: "field__label" %>
      <.input form={@form} type={@type} field={@field} disabled={@immutable} />
      <%= error_tag @form, @field %>
    </div>
    """
  end

  def input(assigns = %{type: :string}) do
    ~H"""
    <%= text_input @form, @field, class: "field__text", disabled: @disabled %>
    """
  end

  def input(assigns = %{type: :boolean}) do
    ~H"""
    <div class="form__checkbox">
      <%= checkbox @form, @field, class: "field__checkbox", disabled: @disabled %>
    </div>
    """
  end

  def input(assigns = %{type: :date}) do
    ~H"""
    <%= date_input @form, @field, class: "field__date", disabled: @disabled %>
    """
  end

  def input(assigns = %{type: number}) when number in [:integer, :id] do
    ~H"""
    <div class="form__number">
      <%= number_input @form, @field, class: "field__number", disabled: @disabled %>
    </div>
    """
  end

  def input(assigns = %{type: type}) when type in [:naive_datetime, :utc_datetime] do
    ~H"""
    <div class="form__time">
      <%= datetime_local_input @form, @field, class: "field__time", disabled: @disabled %>
    </div>
    """
  end

  def input(assigns = %{type: {_, Ecto.Enum, %{mappings: mappings}}}) do
    ~H"""
    <%= select @form, @field, mappings, disabled: @disabled, class: "field__select" %>
    """
  end

  defp fields_for_embed({_, _, %{related: schema}}), do: fields(schema, %{})
end
