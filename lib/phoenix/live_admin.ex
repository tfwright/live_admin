defmodule Phoenix.LiveAdmin do
  def find_belongs_assoc_by_fk(resource, field_name) do
    resource.__schema__(:associations)
    |> Enum.find_value(fn assoc_name ->
      resource.__schema__(:association, assoc_name)
      |> case do
        assoc = %{owner_key: ^field_name, relationship: :parent} -> assoc
        _ -> nil
      end
    end)
  end

  def resource_label(resource, config) do
    case Map.get(config, :label_with) do
      nil -> resource |> Module.split() |> Enum.join(".")
      {m, f, a} -> apply(m, f, a)
      label when is_binary(label) -> label
    end
  end
end
