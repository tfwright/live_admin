defmodule LiveAdmin do
  @moduledoc docout: [LiveAdmin.READMECompiler]

  defmodule InvalidResourceError do
    defexception message: "invalid resource", plug_status: 404
  end

  def route_with_params(socket, segments, params \\ %{}) do
    params =
      Enum.flat_map(params, fn
        {:prefix, nil} -> []
        pair -> [pair]
      end)

    path =
      segments
      |> List.wrap()
      |> Enum.map(&Phoenix.Param.to_param/1)
      |> Path.join()

    encoded_params =
      params
      |> Enum.into(%{})
      |> Enum.empty?()
      |> case do
        true -> ""
        false -> "?" <> Plug.Conn.Query.encode(params)
      end

    socket.router.__live_admin_path__()
    |> Path.join(path)
    |> Kernel.<>(encoded_params)
  end

  def repo, do: Application.fetch_env!(:live_admin, :ecto_repo)

  def session_store,
    do: Application.get_env(:live_admin, :session_store, __MODULE__.Session.Agent)

  def get_resource!(%{resources: resources, key: key}), do: get_resource!(resources, key)

  def get_resource!(resources, key) when is_binary(key),
    do: Map.get(resources, key) || raise(InvalidResourceError)

  def get_resource!(resources, schema) when is_atom(schema),
    do: Enum.find(resources, &(&1.schema == schema)) || raise(InvalidResourceError)

  def associated_resource(schema, field_name, resources, elem \\ :resource) do
    with %{related: assoc_schema} <-
           schema |> parent_associations() |> Enum.find(&(&1.owner_key == field_name)),
         config when not is_nil(config) <-
           Enum.find(resources, fn {_, resource} -> resource.schema == assoc_schema end) do
      elem(config, if(elem == :key, do: 0, else: 1))
    else
      _ -> nil
    end
  end

  def parent_associations(schema) do
    Enum.flat_map(schema.__schema__(:associations), fn assoc_name ->
      case schema.__schema__(:association, assoc_name) do
        assoc = %{relationship: :parent} -> [assoc]
        _ -> []
      end
    end)
  end

  def resource_title(resource) do
    case get_config(resource, :title_with) do
      nil -> resource.schema |> Module.split() |> Enum.at(-1)
      {m, f, a} -> apply(m, f, a)
      title when is_binary(title) -> title
    end
  end

  def record_label(nil, _), do: nil

  def record_label(record, resource) do
    case get_config(resource, :label_with, :id) do
      {m, f, a} -> apply(m, f, [record | a])
      label when is_atom(label) -> Map.fetch!(record, label)
    end
  end

  def resource_path(resource, base_path),
    do: resource.schema |> Module.split() |> Enum.drop(Enum.count(base_path))

  def get_config(resource_or_config, key, default \\ nil)
  def get_config(%{config: config}, key, default), do: get_config(config, key, default)

  def get_config(config, key, default),
    do: Map.get(config, key, Application.get_env(:live_admin, key, default))
end
