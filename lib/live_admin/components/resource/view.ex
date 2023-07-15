defmodule LiveAdmin.Components.Container.View do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import LiveAdmin, only: [route_with_params: 2, trans: 1]

  alias LiveAdmin.Resource
  alias Phoenix.LiveView.JS

  @impl true
  def render(assigns = %{record: nil}) do
    ~H"""
    <div><%= trans("No record found") %></div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="resource__view">
      <div class="resource__table">
        <dl>
          <%= for {field, _, _} <- Resource.fields(@resource) do %>
            <dt class="field__label"><%= trans(humanize(field)) %></dt>
            <dd><%= Resource.render(@record, field, @resource, @session) %></dd>
          <% end %>
        </dl>
        <div class="form__actions">
          <%= live_redirect(trans("Edit"),
            to: route_with_params(assigns, segments: [:edit, @record]),
            class: "resource__action--btn"
          ) %>
          <%= if @resource.__live_admin_config__(:delete_with) != false do %>
            <button
              class="resource__action--danger"
              data-confirm="Are you sure?"
              phx-click={JS.push("delete", value: %{id: @record.id}, page_loading: true)}
            >
              <%= trans("Delete") %>
            </button>
          <% end %>
          <div class="resource__action--drop">
            <button
              class={"resource__action#{if Enum.empty?(@resource.__live_admin_config__(:actions)), do: "--disabled", else: "--btn"}"}
              disabled={if Enum.empty?(@resource.__live_admin_config__(:actions)), do: "disabled"}
            >
              <%= trans("Run action") %>
            </button>
            <nav>
              <ul>
                <%= for action <- @resource.__live_admin_config__(:actions) do %>
                  <li>
                    <button
                      class="resource__action--link"
                      data-confirm="Are you sure?"
                      phx-click={
                        JS.push("action",
                          value: %{id: @record.id, action: action},
                          page_loading: true
                        )
                      }
                    >
                      <%= action |> to_string() |> humanize() %>
                    </button>
                  </li>
                <% end %>
              </ul>
            </nav>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
