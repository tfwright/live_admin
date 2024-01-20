defmodule LiveAdmin do
  @moduledoc docout: [LiveAdmin.READMECompiler]

  @doc """
  Defines [NimbleOptions](https://hexdocs.pm/nimble_options/NimbleOptions.html) schema for configuration that can be set at all levels (resource, scope, and application).

  - `components` - Modules implementing LiveViews to use in place of various UI views
  - `ecto_repo` - Repo to use for running Ecto queries (`find`, `all` etc.)
  - `render_with` - Function controlling how fields are rendered in the list table
  - `delete_with` - Function implementing deletion of a record
  - `update_with` - Function controlling updating a record
  - `validate_with` - Function controlling validation of a record changeset
  - `create_with` - Function implementing creation of a resource
  - `list_with` - Function implementing listing of a resource
  - `label_with` - Function implementing display text for a field
  - `title_with` - Function implementing display text for a resource
  - `hidden_fields` - List of fields that should not be displayed in UI
  - `immutable_fields` - List of fields that should be editable in UI
  - `actions` - List of functions that take a specific record as their first arg
  - `tasks` - List of functions that take a resource as their first arg
  """
  def base_configs_schema do
    [
      components: [
        type: :non_empty_keyword_list,
        keys: [
          nav: [type: :atom],
          home: [type: :atom],
          session: [type: :atom],
          new: [type: :atom],
          edit: [type: :atom],
          list: [type: :atom],
          view: [type: :atom]
        ]
      ],
      ecto_repo: [
        type: :atom
      ],
      render_with: [
        type: {:or, [:atom, :mfa]}
      ],
      delete_with: [
        type: {:or, [:atom, :mfa]}
      ],
      list_with: [
        type: {:or, [:atom, :mfa]}
      ],
      create_with: [
        type: {:or, [:atom, :mfa]}
      ],
      update_with: [
        type: {:or, [:atom, :mfa]}
      ],
      validate_with: [
        type: {:or, [:atom, :mfa]}
      ],
      hidden_fields: [
        type: {:list, :atom}
      ],
      immutable_fields: [
        type: {:list, :atom}
      ],
      actions: [
        type: {:or, [{:list, :atom}, :non_empty_keyword_list]}
      ],
      tasks: [
        type: {:or, [{:list, :atom}, :non_empty_keyword_list]}
      ],
      label_with: [
        type: {:or, [:atom, :mfa]}
      ],
      title_with: [
        type: {:or, [:string, :mfa]}
      ]
    ]
  end

  def fetch_config(resource, :components, config),
    do:
      Keyword.merge(
        Keyword.fetch!(config, :components),
        Keyword.get(resource.__live_admin_config__(), :components, [])
      )

  def fetch_config(resource, key, config),
    do: Keyword.get(resource.__live_admin_config__, key) || Keyword.fetch!(config, key)

  def route_with_params(assigns, parts \\ []) do
    resource_path = parts[:resource_path] || assigns.key

    encoded_params =
      parts
      |> Keyword.get(:params, %{})
      |> Enum.into(%{})
      |> then(fn params ->
        if assigns[:prefix] do
          Map.put_new(params, :prefix, assigns[:prefix])
        else
          params
        end
      end)
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

  def associated_resource(schema, field_name, resources, part \\ nil) do
    with %{related: assoc_schema} <-
           schema |> parent_associations() |> Enum.find(&(&1.owner_key == field_name)),
         config when not is_nil(config) <-
           Enum.find(resources, fn {_, resource} ->
             Keyword.fetch!(resource.__live_admin_config__, :schema) == assoc_schema
           end) do
      case part do
        nil -> config
        :key -> elem(config, 0)
        :resource -> elem(config, 1)
      end
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

  def resource_title(resource, session) do
    resource
    |> fetch_config(:title_with, session)
    |> case do
      nil ->
        resource.__live_admin_config__()
        |> Keyword.fetch!(:schema)
        |> Module.split()
        |> Enum.at(-1)

      {m, f, a} ->
        apply(m, f, a)

      title when is_binary(title) ->
        title
    end
  end

  def record_label(nil, _, _), do: nil

  def record_label(record, resource, config) do
    resource
    |> fetch_config(:label_with, config)
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

  def resources(router, base_path) do
    router
    |> Phoenix.Router.routes()
    |> Enum.flat_map(fn
      %{metadata: %{base_path: ^base_path, resource: resource}} -> [resource]
      _ -> []
    end)
  end
end
