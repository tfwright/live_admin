defmodule LiveAdmin.Components.Container do
  use Phoenix.LiveView
  use PhoenixHTMLHelpers

  require Logger

  import LiveAdmin,
    only: [
      route_with_params: 1,
      route_with_params: 2
    ]

  alias LiveAdmin.Resource

  @impl true
  def mount(_params, _session, socket) do
    socket =
      assign(socket, loading: !connected?(socket))

    {:ok, socket}
  end

  @impl true
  def handle_params(
        params = %{"record_id" => id},
        uri,
        socket = %{assigns: %{live_action: action, loading: false}}
      )
      when action in [:edit, :show] do
    socket =
      socket
      |> assign_resource_info(uri)
      |> assign_mod()
      |> assign_repo()
      |> assign_prefix(params)

    record =
      Resource.find(
        id,
        socket.assigns.resource,
        socket.assigns[:prefix],
        socket.assigns.repo,
        socket.assigns.config
      )

    socket = assign(socket, record: record)

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, uri, socket = %{assigns: %{live_action: :index, loading: false}}) do
    socket =
      socket
      |> assign(search: params["s"])
      |> assign_resource_info(uri)
      |> assign_pagination_params(params)
      |> assign_mod()
      |> assign_repo()
      |> assign_prefix(params)
      |> redirect_with_params(params)

    {:noreply, socket}
  end

  @impl true
  def handle_params(params, uri, socket = %{assigns: %{live_action: :create}}),
    do:
      {:noreply,
       socket
       |> assign_resource_info(uri)
       |> assign_mod()
       |> assign_repo()
       |> assign_prefix(params)}

  def handle_params(_, _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_locale", %{"locale" => locale}, socket) do
    new_session = Map.put(socket.assigns.session, :locale, locale)

    LiveAdmin.session_store().persist!(new_session)

    socket =
      socket
      |> assign(:session, new_session)
      |> push_navigate(to: route_with_params(socket.assigns))

    {:noreply, socket}
  end

  @impl true
  def render(assigns = %{loading: true}), do: ~H"LOADING"

  def render(assigns) do
    ~H"""
    {render(@live_action, assigns)}
    """
  end

  def render(:index, assigns) do
    ~H"""
    <.live_component
      module={@mod}
      id="index"
      key={@key}
      resource={@resource}
      page={@page}
      sort_attr={@sort_attr}
      sort_dir={@sort_dir}
      search={@search}
      prefix={@prefix}
      per={@per}
      session={@session}
      base_path={@base_path}
      resources={@resources}
      repo={@repo}
      config={@config}
    />
    """
  end

  def render(:create, assigns) do
    ~H"""
    <.live_component
      module={@mod}
      id="form"
      action="create"
      session={@session}
      key={@key}
      resources={@resources}
      resource={@resource}
      prefix={@prefix}
      base_path={@base_path}
      repo={@repo}
      config={@config}
    />
    """
  end

  def render(:edit, assigns) do
    ~H"""
    <.live_component
      module={@mod}
      id="form"
      action="update"
      session={@session}
      key={@key}
      record={@record}
      resources={@resources}
      resource={@resource}
      prefix={@prefix}
      repo={@repo}
      base_path={@base_path}
      config={@config}
    />
    """
  end

  def render(:show, assigns) do
    ~H"""
    <.live_component
      module={@mod}
      id="show"
      record={@record}
      resource={@resource}
      resources={@resources}
      session={@session}
      key={@key}
      base_path={@base_path}
      prefix={@prefix}
      repo={@repo}
      config={@config}
    />
    """
  end

  defp assign_prefix(socket, params) do
    socket.assigns.prefix_options
    |> Enum.find(fn option ->
      to_string(option) == Map.get(params, "prefix", socket.assigns.session.prefix)
    end)
    |> case do
      nil ->
        assign_and_presist_prefix(socket, nil)

      prefix ->
        assign_and_presist_prefix(socket, prefix)
    end
  end

  defp assign_and_presist_prefix(socket, prefix) do
    new_session = Map.put(socket.assigns.session, :prefix, prefix)

    LiveAdmin.session_store().persist!(new_session)

    assign(socket, prefix: prefix, session: new_session)
  end

  defp assign_resource_info(socket, uri) do
    %URI{host: host, path: path} = URI.parse(uri)

    %{resource: {key, mod}} = Phoenix.Router.route_info(socket.router, "GET", path, host)

    assign(socket, key: key, resource: mod)
  end

  defp assign_mod(socket = %{assigns: %{resource: resource, live_action: action, config: config}}) do
    mod =
      resource
      |> LiveAdmin.fetch_config(:components, config)
      |> Keyword.fetch!(action)

    assign(socket, :mod, mod)
  end

  defp assign_repo(socket = %{assigns: %{resource: resource, config: config}}) do
    repo = LiveAdmin.fetch_config(resource, :ecto_repo, config)

    prefix_options =
      if function_exported?(repo, :prefixes, 0) do
        repo.prefixes()
      else
        []
      end

    assign(socket, repo: repo, prefix_options: prefix_options)
  end

  defp assign_pagination_params(socket, params) do
    params =
      Map.new(params, fn
        {"sort-attr", val} -> {"sort_attr", val}
        {"sort-dir", val} -> {"sort_dir", val}
        pair -> pair
      end)

    types =
      %{
        page: :integer,
        per: :integer,
        sort_attr:
          Ecto.ParameterizedType.init(Ecto.Enum,
            values:
              socket.assigns.resource
              |> LiveAdmin.Resource.fields(socket.assigns.config)
              |> Enum.map(fn {field, _, _} -> field end)
          ),
        sort_dir: Ecto.ParameterizedType.init(Ecto.Enum, values: [:asc, :desc])
      }

    defaults = %{
      page: 1,
      sort_attr: LiveAdmin.primary_key!(socket.assigns.resource),
      sort_dir: :asc,
      per: socket.assigns.session.index_page_size
    }

    params =
      {defaults, types}
      |> Ecto.Changeset.cast(params, Map.keys(types))
      |> Ecto.Changeset.apply_action!(:update)

    assign(socket, params)
  end

  defp redirect_with_params(socket, params) do
    if Enum.all?(["per", "page", "sort-attr", "sort-dir"], &Map.has_key?(params, &1)) &&
         Map.get(params, "prefix") == socket.assigns.prefix do
      socket
    else
      push_navigate(socket,
        to:
          route_with_params(socket.assigns,
            params: Map.take(socket.assigns, [:per, :page, :sort_attr, :sort_dir, :prefix])
          )
      )
    end
  end
end
