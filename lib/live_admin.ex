defmodule LiveAdmin do
  @moduledoc docout: [LiveAdmin.READMECompiler]

  def route_with_params(assigns, parts \\ []) do
    resource_path = parts[:resource_path] || assigns.key

    encoded_params =
      parts
      |> Keyword.get(:params, [])
      |> Enum.into(%{})
      |> Enum.flat_map(fn
        {_, nil} -> []
        {:sort_attr, val} -> [{:"sort-attr", val}]
        {:sort_dir, val} -> [{:"sort-dir", val}]
        {:search, val} -> [{:s, val}]
        pair -> [pair]
      end)
      |> Enum.into(%{})
      |> case do
        params when map_size(params) > 0 -> "?" <> Plug.Conn.Query.encode(params)
        _ -> ""
      end

    Path.join(
      [assigns.base_path, resource_path] ++
        Enum.map(parts[:segments] || [], &Phoenix.Param.to_param/1)
    ) <>
      encoded_params
  end

  def session_store,
    do: Application.get_env(:live_admin, :session_store, __MODULE__.Session.Agent)

  def associated_resource(schema, field_name, resources, elem \\ :resource) do
    with %{related: assoc_schema} <-
           schema |> parent_associations() |> Enum.find(&(&1.owner_key == field_name)),
         config when not is_nil(config) <-
           Enum.find(resources, fn {_, resource} ->
             resource.__live_admin_config__(:schema) == assoc_schema
           end) do
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
    :title_with
    |> resource.__live_admin_config__()
    |> case do
      nil -> resource.__live_admin_config__(:schema) |> Module.split() |> Enum.at(-1)
      {m, f, a} -> apply(m, f, a)
      title when is_binary(title) -> title
    end
  end

  def record_label(nil, _), do: nil

  def record_label(record, resource) do
    :label_with
    |> resource.__live_admin_config__()
    |> case do
      {m, f, a} -> apply(m, f, [record | a])
      label when is_atom(label) -> Map.fetch!(record, label)
    end
  end

  def use_i18n?, do: gettext_backend() != LiveAdmin.Gettext

  def trans(string, opts \\ []) do
    args =
      [gettext_backend(), string]
      |> then(fn base_args ->
        if opts[:inter], do: base_args ++ [opts[:inter]], else: base_args
      end)

    apply(Gettext, :gettext, args)
  end

  def gettext_backend, do: Application.get_env(:live_admin, :gettext_backend, LiveAdmin.Gettext)
end
