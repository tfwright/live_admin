defmodule LiveAdmin do
  @moduledoc docout: [LiveAdmin.READMECompiler]

  @type mod_func :: {module(), :atom}
  @type func_ref :: atom() | mod_func()
  @type func_list :: [func_ref] | keyword(func_ref)
  @type field_list :: [:atom]

  @options_schema [
    components: [
      type: :non_empty_keyword_list,
      doc: "Overrides portions of the UI with custom LiveComponent modules.",
      type_doc: "list of modules implementing LiveComponent overrides of LiveAdmin views",
      keys: [
        nav: [type: :atom],
        home: [type: :atom],
        session: [type: :atom],
        create: [type: :atom],
        edit: [type: :atom],
        index: [type: :atom],
        show: [type: :atom]
      ]
    ],
    ecto_repo: [
      type: :atom,
      doc: "Required. Must be set at the application or scope level.",
      type_doc: "Ecto Repo used to query resource"
    ],
    query_with: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc: "Customizes how records are fetched. Receives the resource and search term and should return an Ecto queryable. Useful for adding preloads or custom search logic. When not set, uses the schema with built-in search.",
      type_doc: "`t:func_ref/0` returning an Ecto queryable"
    ],
    render_with: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc: "Customizes how field values are displayed. Receives the record, field name, and session. Should return a string or `Phoenix.HTML.Safe` value to render HTML. When not set, uses built-in type-based rendering.",
      type_doc: "`t:func_ref/0` used to convert field values to strings when rendering"
    ],
    delete_with: [
      type: {:or, [{:in, [false]}, :atom, {:tuple, [:atom, :atom]}]},
      doc: "Customizes how records are deleted. Can be set to `false` to disable. When not set, uses `Repo.delete`.",
      type_doc: "`t:func_ref/0` or `false`"
    ],
    create_with: [
      type: {:or, [{:in, [false]}, :atom, {:tuple, [:atom, :atom]}]},
      doc: "Customizes how records are created. Can be set to `false` to disable. When not set, builds a changeset that casts all fields with no validations and calls `Repo.insert`.",
      type_doc: "`t:func_ref/0` or `false`"
    ],
    update_with: [
      type: {:or, [{:in, [false]}, :atom, {:tuple, [:atom, :atom]}]},
      doc: "Customizes how records are updated. Can be set to `false` to disable. When not set, builds a changeset that casts all fields with no validations and calls `Repo.update`.",
      type_doc: "`t:func_ref/0` or `false`"
    ],
    validate_with: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc: "Customizes how changesets are validated in create/update forms. When not set, no additional validation is applied.",
      type_doc: "`t:func_ref/0`"
    ],
    label_with: [
      type: {:or, [:atom, {:tuple, [:atom, :atom]}]},
      doc: "Customizes how records are identified in the UI. When not set, uses the primary key.",
      type_doc: "`t:func_ref/0`"
    ],
    title_with: [
      type: {:or, [:string, {:tuple, [:atom, :atom]}]},
      doc: "Customizes the heading displayed for a resource. When not set, uses the schema module name.",
      type_doc: "string literal or `t:func_ref/0`"
    ],
    hidden_fields: [
      type: {:list, :atom},
      default: [],
      doc: "Specifies fields to hide from all views.",
      type_doc: "`t:field_list/0`"
    ],
    immutable_fields: [
      type: {:list, :atom},
      default: [],
      doc: "Specifies fields to disable in create/update forms.",
      type_doc: "`t:field_list/0`"
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
      default: [],
      doc: "Defines functions that operate on a specific record.",
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
      default: [],
      doc: "Defines functions that operate on a resource as a whole.",
      type_doc:
        "`t:func_list/0` taking a query, LiveAdmin session, and any extra args"
    ]
  ]
  @doc """
  Defines [NimbleOptions](https://hexdocs.pm/nimble_options/NimbleOptions.html) schema for configuration that can be set at all levels (resource, scope, and application).

  Used internally to validate configuration in apps using LiveAdmin.

  Supported options:
  #{@options_schema |> NimbleOptions.new!() |> NimbleOptions.docs()}
  """
  def base_configs_schema, do: @options_schema

  def fetch_function(resource, config, function_type, function)
      when function_type in [:tasks, :actions] and is_atom(function) do
    with result = {_, m, f, _} <-
           extract_function_from_config(resource, config, function_type, function),
         docs when is_map(docs) <- extract_function_docs(m, f) do
      Tuple.insert_at(result, tuple_size(result), docs)
    end
  end

  def fetch_config(resource, :components, config),
    do:
      Keyword.merge(
        Keyword.fetch!(config, :components),
        Keyword.get(resource.__live_admin_config__(), :components, [])
      )

  def fetch_config(resource, key, config),
    do: Keyword.get(resource.__live_admin_config__(), key, Keyword.get(config, key))

  def primary_key!(resource) do
    [key] = Keyword.fetch!(resource.__live_admin_config__(), :schema).__schema__(:primary_key)

    key
  end

  def announce(message, type, session),
    do: LiveAdmin.PubSub.broadcast(session.id, {:announce, %{message: message, type: type}})

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

  @default_function_arity 2
  defp extract_function_from_config(resource, session, function_type, function) do
    resource
    |> LiveAdmin.fetch_config(function_type, session)
    |> Enum.find_value(:error, fn
      {name, {m, f, a}} -> name == function && {name, m, f, a}
      {name, {m, f}} -> name == function && {name, m, f, @default_function_arity}
      {m, f, a} -> f == function && {f, m, f, a}
      {m, f} -> f == function && {f, m, f, @default_function_arity}
      name -> name == function && {name, resource, name, @default_function_arity}
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

  def safe_render(val) when is_list(val), do: inspect(val, pretty: true)

  def safe_render(val) do
    to_string(val)
  rescue
    _ -> inspect(val, pretty: true)
  end
end
