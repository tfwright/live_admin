defmodule Phoenix.LiveAdmin do
  def associated_resource(resource, field_name, resources) do
    with %{related: assoc_schema} <-
           resource |> parent_associations() |> Enum.find(& &1.owner_key == field_name),
         config <- Enum.find(resources, :missing, fn {_, {mod, _}} -> mod == assoc_schema end) do
      config
    else
      _ -> nil
    end
  end

  def parent_associations(resource) do
    Enum.flat_map(resource.__schema__(:associations), fn assoc_name ->
      case resource.__schema__(:association, assoc_name) do
        assoc = %{relationship: :parent} -> [assoc]
        _ -> []
      end
    end)
  end

  def resource_title(resource, config, base_path) do
    case Map.get(config, :title_with) do
      nil -> resource |> resource_path(base_path) |> Enum.join(".")
      {m, f, a} -> apply(m, f, a)
      title when is_binary(title) -> title
    end
  end

  def record_label(record, config) do
    case Map.get(config, :label_with, :id) do
      {m, f, a} -> apply(m, f, [record, a])
      label when is_atom(label) -> Map.fetch!(record, label)
    end
  end

  def resource_path(resource, base_path),
    do: resource |> Module.split() |> Enum.drop(Enum.count(base_path))
end
