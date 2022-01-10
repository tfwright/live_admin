defmodule Phoenix.LiveAdmin.Components.Resource.Index do
  use Phoenix.Component
  use Phoenix.HTML

  import Phoenix.LiveAdmin.Components.Resource, only: [fields: 2, list: 3, route_with_params: 3]

  def render(assigns) do
    ~H"""
    <div class="resource__list">
      <table class="resource__table">
        <thead>
          <tr>
            <%= for {field, _} <- fields(@resource, @config) do %>
              <th class="resource__header"><%= humanize(field) %></th>
            <% end %>
            <th class="resource__header">Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= for record <- @records do %>
            <tr>
              <%= for {field, _} <- fields(@resource, @config) do %>
                <td class="resource__cell">
                  <%= record |> Map.fetch!(field) |> inspect() %>
                </td>
              <% end %>
              <td class="resource__cell">
                <%= live_redirect "Edit", to: route_with_params(@socket, [:edit, @key, record.id], assigns[:params]), class: "resource__action--btn" %>
                <%= link "Delete", to: "#", "data-confirm": "Are you sure?", "phx-click": "delete", "phx-value-id": record.id, class: "resource__action--btn" %>
              </td>
            </tr>
          <% end %>
        </tbody>
        <tfoot>
          <tr>
            <td class="w-full" colspan={fields(@resource, @config) |> Enum.count()}>
              <%= if @page > 1, do: live_patch "Prev", to: @socket.router.__helpers__().resource_path(@socket, :list, @key, page: @page - 1), class: "resource__action--btn" %>
              <%= live_patch "Next", to: @socket.router.__helpers__().resource_path(@socket, :list, @key, page: @page + 1), class: "resource__action--btn" %>
            </td>
          </tr>
        </tfoot>
      </table>
    </div>
    """
  end
end
