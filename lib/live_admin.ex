defmodule LiveAdmin do
  @moduledoc docout: [LiveAdmin.READMECompiler]
  def repo, do: Application.fetch_env!(:live_admin, :ecto_repo)

  def get_resource(%{resources: resources, key: key}), do: get_resource(resources, key)
  def get_resource(resources, key) when is_binary(key), do: Map.fetch!(resources, key)

  def get_resource(resources, schema) when is_atom(schema),
    do: Enum.find(resources, &(&1.schema == schema))

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

  def resource_title(resource, base_path) do
    case get_config(resource, :title_with) do
      nil -> resource |> resource_path(base_path) |> Enum.join(".")
      {m, f, a} -> apply(m, f, a)
      title when is_binary(title) -> title
    end
  end

  def record_label(nil, _), do: nil

  def record_label(record, resource) do
    case get_config(resource.config, :label_with, :id) do
      {m, f, a} -> apply(m, f, [record | a])
      label when is_atom(label) -> Map.fetch!(record, label)
    end
  end

  def resource_path(resource, base_path),
    do: resource.schema |> Module.split() |> Enum.drop(Enum.count(base_path))

  def get_config(config, key, default \\ nil),
    do: Map.get(config, key, Application.get_env(:live_admin, key, default))
end
