defmodule Phoenix.LiveAdmin.Components.Resource.Form do
  use Phoenix.Component
  use Phoenix.HTML

  import Phoenix.LiveAdmin.ErrorHelpers
  import Phoenix.LiveAdmin.Components.Resource, only: [fields: 2]

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

  def field(assigns = %{type: :id}), do: ~H""

  def field(assigns = %{type: {_, Ecto.Embedded, _}}) do
    ~H"""
    <div>
      <h2 class="embed__title"><%= @field %></h2>
      <div class="embed__group">
        <%= unless @immutable do %>
          <%= inputs_for @form, @field, fn fp -> %>
            <%= for {field, type} <- fields_for_embed(@type) do %>
              <.field field={field} type={type} form={fp} />
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

  def input(assigns = %{type: :integer}) do
    ~H"""
    <div class="form__number">
      <%= number_input @form, @field, class: "field__number", disabled: @disabled %>
    </div>
    """
  end

  def input(assigns = %{type: type}) when type in [:naive_datetime, :utc_datetime] do
    ~H"""
    <div class="form__time">
      <%= datetime_select @form, @field, class: "field__time", year: [disabled: @disabled], month: [disabled: @disabled], day: [disabled: @disabled], hour: [disabled: @disabled], minute: [disabled: @disabled] %>
    </div>
    """
  end

  def input(assigns), do: ~H""

  defp fields_for_embed({_, _, %{related: schema}}), do: fields(schema, %{})
end
