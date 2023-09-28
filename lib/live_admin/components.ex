defmodule LiveAdmin.Components do
  use Phoenix.Component
  use Phoenix.HTML

  alias LiveAdmin.Components.Container.Form
  alias Phoenix.LiveView.JS

  slot(:inner_block, required: true)

  attr(:label, :string, required: true)
  attr(:disabled, :boolean, default: false)
  attr(:items, :list, default: [])
  attr(:orientation, :atom, values: [:up, :down], default: :down)
  attr(:id, :string, default: nil)

  def dropdown(assigns) do
    ~H"""
    <div id={@id} class="resource__action--drop">
      <%= if @orientation == :up do %>
        <.list items={@items} inner_block={@inner_block} />
      <% end %>
      <button
        class={"resource__action#{if @disabled, do: "--disabled", else: "--btn"}"}
        disabled={if @disabled, do: "disabled"}
      >
        <%= @label %>
      </button>
      <%= if @orientation == :down do %>
        <.list items={@items} inner_block={@inner_block} />
      <% end %>
    </div>
    """
  end

  def embed(assigns) do
    ~H"""
    <div id={@id <> "_container"} class="embed__group" phx-hook="EmbedComponent">
      <%= unless @disabled do %>
        <.inputs_for :let={embed_form} field={@form[@field]} skip_hidden={true}>
          <div class="embed__item">
            <%= if match?({_, _, %{cardinality: :many}}, @type) do %>
              <input
                type="hidden"
                name={input_name(@form, LiveAdmin.View.sort_param_name(@field)) <> "[]"}
                value={embed_form.index}
                class="embed__index"
              />
              <input
                type="checkbox"
                name={input_name(@form, LiveAdmin.View.drop_param_name(@field)) <> "[]"}
                value={embed_form.index}
                class="embed__drop"
              />
              <a href="#" class="button__remove" phx-click={JS.dispatch("live_admin:embed_drop")} />
              <%= if embed_form.index > 0 do %>
                <a
                  href="#"
                  class="button__up"
                  data-dir="-1"
                  phx-click={JS.dispatch("live_admin:move_embed")}
                />
              <% end %>
              <%= if embed_form.index < Enum.count(List.wrap(input_value(@form, @field))) - 1 do %>
                <a
                  href="#"
                  class="button__down"
                  data-dir="-1"
                  phx-click={JS.dispatch("live_admin:move_embed")}
                />
              <% end %>
            <% else %>
              <input type="hidden" name={input_name(@form, @field)} value="" disabled />
              <a href="#" class="button__remove" phx-click={JS.dispatch("live_admin:embed_delete")} />
            <% end %>
            <div>
              <%= for {field, type, _} <- embed_fields(@type) do %>
                <Form.field
                  field={field}
                  type={type}
                  form={embed_form}
                  immutable={false}
                  resource={@resource}
                  resources={@resources}
                  session={@session}
                  prefix={@prefix}
                  repo={@repo}
                />
              <% end %>
            </div>
          </div>
        </.inputs_for>
        <%= if match?({_, _, %{cardinality: :many}}, @type) || !input_value(@form, @field) do %>
          <input
            type="checkbox"
            name={input_name(@form, LiveAdmin.View.sort_param_name(@field)) <> "[]"}
            class="embed__sort"
          />
          <a href="#" phx-click={JS.dispatch("live_admin:embed_add")} class="button__add" />
        <% end %>
      <% else %>
        <pre><%= @form |> input_value(@field) |> inspect() %></pre>
      <% end %>
    </div>
    """
  end

  defp list(assigns) do
    ~H"""
    <div>
      <nav>
        <ul>
          <%= for item <- @items do %>
            <li><%= render_slot(@inner_block, item) %></li>
          <% end %>
        </ul>
      </nav>
    </div>
    """
  end

  defp embed_fields({_, _, %{related: schema}}),
    do: Enum.map(schema.__schema__(:fields), &{&1, schema.__schema__(:type, &1), []})
end
