defmodule LiveAdmin.Components.Container.Form.Embed do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias LiveAdmin.Components.Container.Form
  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns = %{form: form, field: field}, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:embed_forms, form.impl.to_form(form.source, form, field, []))

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id <> "_container"} class="embed__group" phx-hook="EmbedComponent">
      <%= unless @disabled do %>
        <%= hidden_input(@form, @field, value: "delete") %>
        <input type="checkbox" name={input_name(@form, :ecto_sort_position) <> "[]"} class="hidden" />
        <%= for embed_form <- @embed_forms do %>
          <div class="embed__item">
            <input
              type="hidden"
              name={input_name(@form, :ecto_sort_position) <> "[]"}
              value={embed_form.index}
              class="embed__index"
            />
            <a
              href="#"
              class="button__remove"
              phx-click={
                JS.push("remove",
                  value: %{idx: embed_form.index},
                  target: @myself,
                  page_loading: true
                )
              }
            />
            <%= if embed_form.index > 0 do %>
              <a href="#" class="button__up" phx-click={JS.dispatch("live_admin:embed_up")} />
            <% end %>
            <%= if embed_form.index < Enum.count(@embed_forms) - 1 do %>
              <a href="#" class="button__down" phx-click={JS.dispatch("live_admin:embed_down")} />
            <% end %>
            <div>
              <%= for {field, type, _} <- fields(@type) do %>
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
        <% end %>
        <%= if match?({_, _, %{cardinality: :many}}, @type) || Enum.empty?(@embed_forms) do %>
          <a
            href="#"
            phx-click={
              JS.push("add",
                target: @myself,
                page_loading: true
              )
            }
            class="button__add"
          />
        <% end %>
      <% else %>
        <pre><%= @form |> input_value(@field) |> inspect() %></pre>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("remove", params, socket) do
    idx = params |> Map.fetch!("idx") |> Kernel.||(0)

    socket =
      socket
      |> assign(embed_forms: List.delete_at(socket.assigns.embed_forms, idx))
      |> push_event("change", %{})

    {:noreply, socket}
  end

  def handle_event("add", _params, socket) do
    idx = Enum.count(socket.assigns.embed_forms)

    new_form =
      to_form(%{},
        as: input_name(socket.assigns.form, socket.assigns.field) <> "[#{idx}]",
        id: input_id(socket.assigns.form, socket.assigns.field) <> "_#{idx}"
      )

    socket =
      socket
      |> assign(embed_forms: socket.assigns.embed_forms ++ [new_form])
      |> push_event("change", %{})

    {:noreply, socket}
  end

  defp fields({_, _, %{related: schema}}),
    do: Enum.map(schema.__schema__(:fields), &{&1, schema.__schema__(:type, &1), []})
end
