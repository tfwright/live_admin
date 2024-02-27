defmodule LiveAdmin do
  @moduledoc docout: [LiveAdmin.READMECompiler]

  @type mod_func :: {module(), :atom}
  @type func_ref :: :atom | mod_func() | :mfa
  @type func_list :: [func_ref] | keyword(func_ref)
  @type field_list :: [:atom]

  @options_schema [
    components: [
      type: :non_empty_keyword_list,
      type_doc: "list of modules implementing LiveComponent overrides of LiveAdmin views",
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
      type: :atom,
      type_doc: "Ecto Repo used to query resource"
    ],
    list_with: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      type_doc:
        "`t:func_ref/0` returning `{records, count}` used to fetch records in LiveAdmin :list component"
    ],
    render_with: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      type_doc:
        "`t:func_ref/0` used to convert field values to string in LiveAdmin :list component"
    ],
    delete_with: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      type_doc: "`t:func_ref/0` or `false` to disable deleting records"
    ],
    create_with: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      type_doc: "`t:func_ref/0` or `false` to disable creating records"
    ],
    update_with: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      type_doc: "`t:func_ref/0` or `false` to disable updating records"
    ],
    validate_with: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      type_doc:
        "`t:func_ref/0` used to validate create/update changesets in LiveAdmin :form component"
    ],
    label_with: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      type_doc:
        "`t:func_ref/0` used to convert (association) record to string in LiveAdmin SearchSelect component"
    ],
    title_with: [
      type: {:or, [:string, {:tuple, [:atom, :atom]}]},
      type_doc: "string literal or MFA returning a string used to render LiveAdmin UI heading"
    ],
    hidden_fields: [
      type: {:list, :atom},
      type_doc: "`t:field_list/0` to be hidden from LiveView"
    ],
    immutable_fields: [
      type: {:list, :atom},
      type_doc: "`t:field_list/0` to be disabled in LiveAdmin :form component"
    ],
    actions: [
      type:
        {:list,
         {:or,
          [
            :atom,
            {:tuple, [:atom, :atom]},
            {:tuple, [:atom, :atom, :integer]},
            {:tuple,
             [:atom, {:or, [{:tuple, [:atom, :atom]}, {:tuple, [:atom, :atom, :integer]}]}]}
          ]}},
      type_doc: "`t:func_list/0` taking a record, LiveAdmin session struct, and any extra args"
    ],
    tasks: [
      type:
        {:list,
         {:or,
          [
            :atom,
            {:tuple, [:atom, :atom]},
            {:tuple, [:atom, :atom, :integer]},
            {:tuple,
             [:atom, {:or, [{:tuple, [:atom, :atom]}, {:tuple, [:atom, :atom, :integer]}]}]}
          ]}},
      type_doc: "`t:func_list/0` taking a LiveAdmin session and any extra args"
    ]
  ]
  @doc """
  Defines [NimbleOptions](https://hexdocs.pm/nimble_options/NimbleOptions.html) schema for configuration that can be set at all levels (resource, scope, and application).

  Used internally to validate configuration in apps using LiveAdmin.

  Supported options:
  #{@options_schema |> NimbleOptions.new!() |> NimbleOptions.docs()}
  """
  def base_configs_schema, do: @options_schema

  def fetch_function(resource, session, function_type, function)
      when function_type in [:tasks, :actions] and is_atom(function) do
    with result = {_, m, f, _} <-
           extract_function_from_config(resource, session, function_type, function),
         docs when is_map(docs) <- extract_function_docs(m, f) do
      Tuple.append(result, docs)
    end
  end

  def fetch_config(resource, :components, config),
    do:
      Keyword.merge(
        Keyword.fetch!(config, :components),
        Keyword.get(resource.__live_admin_config__(), :components, [])
      )

  def fetch_config(resource, key, config),
    do: Keyword.get(resource.__live_admin_config__, key) || Keyword.fetch!(config, key)

  def primary_key!(resource) do
    [key] = Keyword.fetch!(resource.__live_admin_config__(), :schema).__schema__(:primary_key)

    key
  end

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

    segments =
      Enum.map(
        parts[:segments] || [],
        fn segment ->
          cond do
            is_struct(segment) && Phoenix.Param.impl_for(segment) ->
              Phoenix.Param.to_param(segment)

            true ->
              to_string(segment)
          end
        end
      )

    Path.join([assigns.base_path, resource_path] ++ segments) <> encoded_params
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

      {m, f} ->
        apply(m, f, [])

      title when is_binary(title) ->
        title
    end
  end

  def record_label(nil, _, _), do: nil

  def record_label(record, resource, config) do
    resource
    |> fetch_config(:label_with, config)
    |> case do
      nil -> Map.fetch!(record, LiveAdmin.primary_key!(resource))
      {m, f} -> apply(m, f, [record])
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

  defp extract_function_from_config(resource, session, function_type, function) do
    default_arity = if function_type == :tasks, do: 1, else: 2

    resource
    |> LiveAdmin.fetch_config(function_type, session)
    |> Enum.find_value(:error, fn
      {name, {m, f, a}} -> name == function && {name, m, f, a}
      {name, {m, f}} -> name == function && {name, m, f, default_arity}
      {m, f, a} -> f == function && {f, m, f, a}
      {m, f} -> f == function && {f, m, f, default_arity}
      name -> name == function && {name, resource, name, default_arity}
    end)
  end

  def extract_function_docs(module, function) do
    with {_, _, _, _, _, _, module_docs} <- Code.fetch_docs(module),
         function_docs <-
           Enum.find_value(module_docs, %{}, fn {{_, name, _}, _, _, docs, _} ->
             name == function && is_map(docs) && docs
           end) do
      function_docs
    else
      {:error, _} -> %{}
    end
  end
end
