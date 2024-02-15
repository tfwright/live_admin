defmodule LiveAdmin.Components do
  use Phoenix.Component
  import Phoenix.HTML.Form
  use PhoenixHTMLHelpers

  alias LiveAdmin.Components.Container.Form
  alias Phoenix.LiveView.JS

  slot(:inner_block, required: true)
  slot(:control)
  slot(:empty_label)

  attr(:label, :string, required: true)
  attr(:disabled, :boolean, default: false)
  attr(:items, :list, default: [])
  attr(:orientation, :atom, values: [:up, :down], default: :down)
  attr(:id, :string, default: nil)
  attr(:base_class, :string, default: "resource__action")

  def dropdown(assigns) do
    ~H"""
    <div id={@id} class={"#{@base_class}--drop"} tabindex="0">
      <%= if @orientation == :up do %>
        <.list items={@items} inner_block={@inner_block} />
      <% end %>
      <%= if render_slot(@control) do %>
        <%= render_slot(@control) %>
      <% else %>
        <button
          class={"resource__action#{if @disabled, do: "--disabled", else: "--btn"}"}
          disabled={if @disabled, do: "disabled"}
        >
          <%= @label %>
        </button>
      <% end %>
      <%= if @orientation == :down do %>
        <.list items={@items} inner_block={@inner_block} empty_label={@empty_label} />
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
                phx-page-loading
              />
              <input
                type="checkbox"
                name={input_name(@form, LiveAdmin.View.drop_param_name(@field)) <> "[]"}
                value={embed_form.index}
                class="embed__drop"
                phx-page-loading
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
                  data-dir="+1"
                  phx-click={JS.dispatch("live_admin:move_embed")}
                />
              <% end %>
            <% else %>
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
                  config={@config}
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
            phx-page-loading
          />
          <a href="#" phx-click={JS.dispatch("live_admin:embed_add")} class="button__add" />
        <% end %>
        <%= if match?({_, _, %{cardinality: :one}}, @type) do %>
          <input
            type="hidden"
            name={input_name(@form, @field)}
            value=""
            disabled={!!input_value(@form, @field)}
          />
        <% end %>
      <% else %>
        <pre><%= @form |> input_value(@field) |> inspect() %></pre>
      <% end %>
    </div>
    """
  end

  def action_control(assigns) do
    {m, f, []} =
      assigns.resource
      |> LiveAdmin.fetch_config(:actions, assigns.session)
      |> Enum.find_value(fn
        {action_name, mfa} -> action_name == assigns.action && mfa
        action_name -> action_name == assigns.action && {assigns.resource, action_name, []}
      end)

    extra_arg_count =
      :functions
      |> m.__info__()
      |> Enum.find_value(fn {name, arity} -> name == f && arity - 2 end)

    assigns = assign(assigns, extra_arg_count: extra_arg_count)

    ~H"""
    <button
      class="resource__action--link"
      data-action={@action}
      phx-click={
        if @extra_arg_count > 0,
          do:
            JS.show(
              to: "##{@action}-action-modal",
              transition: {"ease-in duration-300", "opacity-0", "opacity-100"}
            ),
          else: JS.dispatch("live_admin:action")
      }
      data-confirm={if @extra_arg_count > 0, do: nil, else: "Are you sure?"}
    >
      <%= @action |> to_string() |> humanize() %>
    </button>
    <%= if @extra_arg_count > 0 do %>
      <.action_modal id={"#{@action}-action-modal"}>
        <pre><%= @action %></pre> action requires additional arguments:
        <.form
          for={Phoenix.Component.to_form(%{})}
          phx-submit={JS.dispatch("live_admin:action") |> JS.hide(to: "##{@action}-action-modal")}
        >
          <input type="hidden" name="name" value={@action} />
          <%= for num <- 1..@extra_arg_count do %>
            <div>
              <label><%= num %></label>
              <input type="text" name="args[]" />
            </div>
          <% end %>
          <input type="submit" value="Execute" />
        </.form>
      </.action_modal>
    <% end %>
    """
  end

  defp action_modal(assigns) do
    ~H"""
    <div
      id={@id}
      class="modal"
      phx-capture-click={
        JS.hide(to: "##{@id}", transition: {"ease-out duration-300", "opacity-100", "opacity-0"})
      }
    >
      <div>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  defp list(assigns) do
    ~H"""
    <div>
      <nav>
        <ul>
          <%= if Enum.empty?(@items) && assigns[:empty_label] do %>
            <li><%= render_slot(@empty_label) %></li>
          <% end %>
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
