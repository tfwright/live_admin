defmodule LiveAdmin.Components.Container.Form.Embed do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias LiveAdmin.Components.Container.Form
  alias Phoenix.LiveView.JS

  import LiveAdmin, only: [trans: 1]

  @impl true
  def update(assigns = %{form: form, field: field}, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:embed_forms, inputs_for(form, field))

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="embed__group">
      <%= unless @disabled do %>
        <%= hidden_input(@form, @field, value: "delete") %>
        <%= for embed_form <- @embed_forms do %>
          <div class="embed__item">
            <div>
              <a
                class="button__remove"
                phx-click={
                  JS.push("remove",
                    value: %{idx: embed_form.index},
                    target: @myself,
                    page_loading: true
                  )
                }
              />
            </div>
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
        <%= if match?({_, _, %{cardinality: :many}}, @type) || input_value(@form, @field) == nil do %>
          <div class="form__actions">
            <a
              href="#"
              phx-click={
                JS.push("add",
                  target: @myself,
                  page_loading: true
                )
              }
              class="resource__action--btn"
            >
              <%= trans("New") %>
            </a>
          </div>
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
