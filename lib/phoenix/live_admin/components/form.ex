defmodule Phoenix.LiveAdmin.Components.Resource.Form do
  use Phoenix.Component
  use Phoenix.HTML

  import Phoenix.LiveAdmin.ErrorHelpers
  import Phoenix.LiveAdmin.Components.Resource, only: [fields: 2]

  def render(assigns) do
    ~H"""
    <%= form_for @changeset , "#", [as: "params", phx_change: "validate", phx_submit: "save", class: "w-3/4 shadow-md p-2"], fn f -> %>
      <%= for {field, type} <- fields(@resource, @config) do %>
        <.field field={field} type={type} form={f} />
      <% end %>
      <div class="text-right">
        <%= submit "Save", class: "inline-flex items-center h-8 px-4 m-2 text-sm text-indigo-100 transition-colors duration-150 bg-indigo-700 rounded-lg focus:shadow-outline hover:bg-indigo-800" %>
      </div>
    <% end %>
    """
  end

  def field(assigns = %{type: {_, Ecto.Embedded, _}}) do
    ~H"""
    <div>
      <h2 class="mb-2 uppercase font-bold text-lg text-grey-darkest"><%= @field %></h2>
      <div class="flex flex-col mb-4 ml-4">
        <%= inputs_for @form, @field, fn fp -> %>
          <%= for {field, type} <- fields_for_embed(@type) do %>
            <.field field={field} type={type} form={fp} />
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  def field(assigns) do
    ~H"""
    <div class="flex flex-col mb-4">
      <%= label @form, @field, class: "mb-2 uppercase font-bold text-lg text-grey-darkest" %>
      <.input form={@form} type={@type} field={@field} />
      <%= error_tag @form, @field %>
    </div>
    """
  end

  def input(assigns = %{type: :string}) do
    ~H"""
    <%= text_input @form, @field, class: "border py-2 px-3 text-grey-darkest"  %>
    """
  end

  def input(assigns = %{type: :boolean}) do
    ~H"""
    <div class="flex-none ml-1">
      <%= checkbox @form, @field, class: "scale-150" %>
    </div>
    """
  end

  def input(assigns = %{type: :date}) do
    ~H"""
    <%= date_input @form, @field %>
    """
  end

  def input(assigns = %{type: :integer}) do
    ~H"""
    <div class="flex-none ml-1">
      <%= number_input @form, @field %>
    </div>
    """
  end

  def input(assigns = %{type: type}) when type in [:naive_datetime, :utc_datetime] do
    ~H"""
    <div class="flex-none ml-1">
      <%= datetime_select @form, @field %>
    </div>
    """
  end

  def input(assigns), do: ~H""

  defp fields_for_embed({_, _, %{related: schema}}), do: fields(schema, %{})
end
