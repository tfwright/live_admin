defmodule Phoenix.LiveAdmin.Components.Resource.Index do
  use Phoenix.Component
  use Phoenix.HTML

  import Phoenix.LiveAdmin.Components.Resource, only: [fields: 2, list: 3, route_with_params: 3]

  def render(assigns) do
    ~H"""
    <div class="resource__list">
      <div class="list__search">
        <div class="flex border-2 rounded-lg">
            <form phx-change="search" >
              <input type="text" class="px-4 py-1 w-60 border-0 h-8" placeholder="Search..." name="query" onkeydown="return event.key != 'Enter'">
            </form>
            <button phx-click="search" phx-value-query="" class="flex items-center justify-center px-2 border-l">
              <svg class="w-6 h-6 text-gray-600" fill="currentColor" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
                <path d="M16.32 14.9l5.39 5.4a1 1 0 0 1-1.42 1.4l-5.38-5.38a8 8 0 1 1 1.41-1.41zM10 16a6 6 0 1 0 0-12 6 6 0 0 0 0 12z" />
              </svg>
            </button>
        </div>
      </div>
      <table class="resource__table">
        <thead>
          <tr>
            <%= for {field, _, _} <- fields(@resource, @config) do %>
              <th class="resource__header"><%= humanize(field) %></th>
            <% end %>
            <th class="resource__header">Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= for record <- @records |> elem(0) do %>
            <tr>
              <%= for {field, _, _} <- fields(@resource, @config) do %>
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
            <td class="w-full" colspan={@resource |> fields(@config) |> Enum.count()}>
              <%= if @page > 1, do: live_patch("Prev", to: route_with_params(@socket, [:list, @key], Map.put(@params, :page, @page - 1)), class: "resource__action--btn"), else: content_tag(:span, "Prev", class: "resource__action--disabled") %>
              <%= if @page < (@records |> elem(1)) / 10, do: live_patch("Next", to: route_with_params(@socket, [:list, @key], Map.put(@params, :page, @page + 1)), class: "resource__action--btn"), else: content_tag(:span, "Next", class: "resource__action--disabled") %>
            </td>
            <td class="text-right p-2"><%= @records |> elem(1) %> total rows</td>
          </tr>
        </tfoot>
      </table>
    </div>
    """
  end
end
