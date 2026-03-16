defmodule LiveAdmin.Components.Nav.Wrapper do
  use Phoenix.LiveView

  @impl true
  def mount(
        _params,
        %{"session_id" => session_id, "base_path" => base_path, "opts" => opts},
        socket
      ) do
    if connected?(socket) do
      :ok = LiveAdmin.PubSub.subscribe(session_id)
    end

    session = LiveAdmin.session_store().load!(session_id)
    resources = LiveAdmin.resources(socket.router, base_path)
    nav_module = get_in(opts, [:components, :nav])

    socket =
      assign(socket,
        session: session,
        base_path: base_path,
        resources: resources,
        config: opts,
        nav_module: nav_module,
        title: Keyword.fetch!(opts, :title),
        resource: nil,
        current_view: nil,
        prefix: nil,
        key: nil
      )

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_info({:nav, %{uri: uri}}, socket) do
    %URI{host: host, path: path} = URI.parse(uri)

    route_info = Phoenix.Router.route_info(socket.router, "GET", path, host)

    {resource, key} =
      case route_info do
        %{resource: {key, mod}} -> {mod, key}
        _ -> {nil, nil}
      end

    {current_view, _, _, _} = route_info.phoenix_live_view

    {:noreply, assign(socket, resource: resource, key: key, current_view: current_view)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <input type="checkbox" id="sidebar-toggle" class="sidebar-toggle-input" checked>
      <.live_component
        id="nav"
        module={@nav_module}
        title={@title}
        base_path={@base_path}
        resources={@resources}
        resource={@resource}
        current_view={@current_view}
        prefix={@prefix}
        key={@key}
        config={@config}
        session={@session}
      />
      {live_render(@socket, LiveAdmin.Components.Nav.Jobs,
        sticky: true,
        id: "jobs",
        session: %{"session_id" => @session.id}
      )}
    </div>
    """
  end
end
