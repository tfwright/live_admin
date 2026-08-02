defmodule LiveAdmin.Resource do
  @moduledoc """
  API for managing Ecto schemas and their individual record instances used internally by LiveAdmin.

  > #### `use LiveAdmin.Resource` {: .info}
  > This is required in any module that should act as a LiveAdmin Resource.
  > If the module is not an Ecto schema, then the `:schema` option must be passed.
  > Using this module will create a __live_admin_config__ module variable and a function
  > to query it, __live_admin_config__/0.
  """

  require Integer

  import Ecto.Query
  import LiveAdmin

  alias Ecto.Changeset

  @doc """
  Configure a module to act as a LiveAdmin resource

  In addition to global options, also accepts `schema` in case the resource
  is not also an Ecto schema.
  """
  defmacro __using__(opts) do
    opts_schema =
      LiveAdmin.base_configs_schema() ++ [schema: [type: :atom, default: __CALLER__.module]]

    quote bind_quoted: [opts: opts, opts_schema: opts_schema] do
      opts = NimbleOptions.validate!(opts, opts_schema)

      @__live_admin_config__ opts

      def __live_admin_config__, do: @__live_admin_config__
    end
  end

  @doc """
  Fetches every record of `resource` whose primary key is contained in `keys`.

  Records are loaded from `repo` within the given schema `prefix` (the Ecto
  query prefix used for multi-tenancy). Returns a list of schema structs.
  """
  def all(keys, resource, prefix, repo) do
    key = LiveAdmin.primary_key!(resource)

    resource.__live_admin_config__()
    |> Keyword.fetch!(:schema)
    |> where([s], field(s, ^key) in ^keys)
    |> repo.all(prefix: prefix)
  end

  @doc """
  Same as `find/5`, but raises `Ecto.NoResultsError` when no record matches.
  """
  def find!(key, resource, prefix, repo, config) do
    find(key, resource, prefix, repo, config) ||
      raise(Ecto.NoResultsError,
        queryable: Keyword.fetch!(resource.__live_admin_config__(), :schema)
      )
  end

  @doc """
  Fetches the single record of `resource` identified by primary key `key`.

  The lookup runs against the query built by `query/3` (so any `query_with`
  override is respected) within the given schema `prefix`. Returns the record,
  or `nil` when it is not found or when `key` cannot be cast to the primary key
  type.
  """
  def find(key, resource, prefix, repo, config) do
    resource
    |> query(nil, config)
    |> repo.get(key, prefix: prefix)
  rescue
    Ecto.Query.CastError -> nil
  end

  @doc """
  Deletes `record`.

  When the resource configures `delete_with`, that function is invoked with
  `record` and the current `session` instead of the default `repo.delete/1`.
  """
  def delete(record, resource, session, repo, config) do
    resource
    |> LiveAdmin.fetch_config(:delete_with, config)
    |> case do
      nil ->
        repo.delete(record)

      {mod, func_name} ->
        apply(mod, func_name, [record, session])

      name when is_atom(name) ->
        apply(resource, name, [record, session])
    end
  end

  @doc """
  Lists records of `resource` for the index view.

  `opts` is an enumerable that tunes the query; all keys are optional:

    * `:page` - one-based page number (default `1`)
    * `:per` - page size (defaults to the session's `index_page_size`)
    * `:sort_attr` - field to order by (defaults to the primary key)
    * `:sort_dir` - `:asc` or `:desc` (default `:asc`)
    * `:search` - search string passed to `query/3`
    * `:prefix` - schema prefix to query within

  Returns a `{records, total_count}` tuple, where `total_count` ignores
  pagination so it reflects the full result set.
  """
  def list(resource, opts, session, repo, config) do
    opts =
      opts
      |> Enum.into(%{})
      |> Map.put_new(:page, 1)
      |> Map.put_new(:per, session.index_page_size)
      |> Map.put_new(:sort_dir, :asc)
      |> Map.put_new(:sort_attr, LiveAdmin.primary_key!(resource))

    query =
      resource
      |> query(opts[:search], config)
      |> limit(^opts[:per])
      |> offset(^((opts[:page] - 1) * opts[:per]))
      |> order_by(^[{opts[:sort_dir], opts[:sort_attr]}])

    {
      repo.all(query, prefix: opts[:prefix]),
      repo.aggregate(
        query |> exclude(:limit) |> exclude(:offset),
        :count,
        prefix: opts[:prefix]
      )
    }
  end

  @doc """
  Builds an `Ecto.Changeset` for `resource`.

  Pass an existing `record` to build an update changeset, or omit it (or pass
  `nil`) to build a changeset over a new struct for creation. `params` are cast
  according to the resource's editable fields, skipping `immutable_fields` and
  handling embeds. This drives the create and edit forms.
  """
  def change(resource, record \\ nil, params \\ %{}, config)

  def change(resource, record, params, config) when is_struct(record) do
    build_changeset(record, resource, params, config)
  end

  def change(resource, nil, params, config) do
    resource.__live_admin_config__()
    |> Keyword.fetch!(:schema)
    |> struct(%{})
    |> build_changeset(resource, params, config)
  end

  @doc """
  Creates a new record of `resource` from `params`.

  When the resource configures `create_with`, that function is invoked with
  `params` and the current `session`. Otherwise a changeset built by `change/4`
  is inserted via `repo`, within the session's prefix.
  """
  def create(resource, params, session, repo, config) do
    resource
    |> LiveAdmin.fetch_config(:create_with, config)
    |> case do
      nil ->
        resource
        |> change(nil, params, config)
        |> repo.insert(prefix: session.prefix)

      {mod, func_name} ->
        apply(mod, func_name, [params, session])

      name when is_atom(name) ->
        apply(resource, name, [params, session])
    end
  end

  @doc """
  Updates `record` with `params`.

  When the resource configures `update_with`, that function is invoked with
  `record`, `params`, and the current `session`. Otherwise a changeset built by
  `change/4` is persisted via the resource's configured `ecto_repo`.
  """
  def update(record, resource, params, session, config) do
    resource
    |> LiveAdmin.fetch_config(:update_with, config)
    |> case do
      nil ->
        repo = LiveAdmin.fetch_config(resource, :ecto_repo, config)

        resource
        |> change(record, params, config)
        |> repo.update()

      {mod, func_name} ->
        apply(mod, func_name, [record, params, session])

      name when is_atom(name) ->
        apply(resource, name, [record, params, session])
    end
  end

  @doc """
  Runs validation for `changeset` and marks it with the `:validate` action.

  When the resource configures `validate_with`, that function receives the
  `changeset` and current `session` and returns the changeset to use; otherwise
  the changeset is returned unchanged. Setting the `:validate` action lets the
  form surface errors without attempting to persist.
  """
  def validate(changeset, resource, session, config) do
    resource
    |> LiveAdmin.fetch_config(:validate_with, config)
    |> case do
      nil -> changeset
      {mod, func_name} -> apply(mod, func_name, [changeset, session])
      name when is_atom(name) -> apply(resource, name, [changeset, session])
    end
    |> Map.put(:action, :validate)
  end

  @doc """
  Returns the displayable fields of `resource`.

  Each entry is a `{field_name, native_type, opts}` tuple, where `native_type`
  is the underlying Ecto type (custom types are resolved to the type they cast
  to) and `opts` carries `immutable: boolean`. Fields listed in the resource's
  `hidden_fields` are excluded, and those in `immutable_fields` are flagged.
  """
  def fields(resource, config) do
    schema = Keyword.fetch!(resource.__live_admin_config__(), :schema)
    hidden_fields = LiveAdmin.fetch_config(resource, :hidden_fields, config)
    immutable_fields = LiveAdmin.fetch_config(resource, :immutable_fields, config)

    schema.__schema__(:fields)
    |> Enum.reject(&(&1 in hidden_fields))
    |> Enum.map(fn field_name ->
      type = schema.__schema__(:type, field_name)
      is_immutable? = field_name in immutable_fields
      native_type = parse_type(type)

      {field_name, native_type, [immutable: is_immutable?]}
    end)
  end

  defp parse_type(type) do
    case type do
      {:parameterized, custom_type, _} ->
        get_custom_type(custom_type)

      custom_type when is_atom(custom_type) ->
        get_custom_type(custom_type)

      _ ->
        type
    end
  end

  defp get_custom_type(custom_type) do
    if function_exported?(custom_type, :type, 0) do
      custom_type.type()
    else
      custom_type
    end
  end

  defp apply_search(query, q, fields) do
    parts = String.split(q, ~r{([^\s]*:)}, include_captures: true, trim: true)

    if parts |> Enum.count() |> Integer.is_odd() do
      [{"*", q}]
    else
      parts
      |> Enum.map(&String.trim/1)
      |> Enum.chunk_every(2)
      |> Enum.map(fn
        [column, param] -> {String.replace(column, ":", ""), param}
      end)
    end
    |> case do
      field_queries when is_list(field_queries) ->
        field_queries
        |> Enum.reduce(query, fn
          {field_key, q}, query ->
            conds =
              fields
              |> Enum.reduce(dynamic([], false), fn {field_name, _, _}, conds ->
                if field_key == "*" || to_string(field_name) == field_key do
                  dynamic(
                    [r],
                    ^conds or ilike(fragment("CAST(? AS text)", field(r, ^field_name)), ^"%#{q}%")
                  )
                else
                  conds
                end
              end)

            where(query, ^conds)
        end)
    end
  end

  defp build_changeset(record = %schema{}, resource, params, config) do
    resource
    |> case do
      :embed ->
        Enum.map(schema.__schema__(:fields), fn field_name ->
          {field_name, schema.__schema__(:type, field_name), []}
        end)

      resource ->
        fields(resource, config)
    end
    |> Enum.reduce(Changeset.cast(record, params, []), fn
      {field_name, {_, {Ecto.Embedded, %{cardinality: :many}}}, _}, changeset ->
        Changeset.cast_embed(changeset, field_name,
          with: fn embed, params ->
            build_changeset(embed, :embed, params, config)
          end,
          sort_param: LiveAdmin.View.sort_param_name(field_name),
          drop_param: LiveAdmin.View.drop_param_name(field_name)
        )

      {field_name, {_, {Ecto.Embedded, %{cardinality: :one}}}, _}, changeset ->
        cond do
          Map.get(params, field_name |> LiveAdmin.View.drop_param_name() |> to_string()) ->
            Changeset.put_change(changeset, field_name, nil)

          Map.get(params, field_name |> LiveAdmin.View.sort_param_name() |> to_string()) ->
            Changeset.put_change(changeset, field_name, %{})

          true ->
            Changeset.cast_embed(changeset, field_name,
              with: fn embed, params -> build_changeset(embed, :embed, params, config) end
            )
        end

      {field_name, type, opts}, changeset ->
        unless Keyword.get(opts, :immutable, false) do
          changeset = Changeset.cast(changeset, params, [field_name])

          if type == :map do
            Changeset.update_change(changeset, field_name, &parse_map_param/1)
          else
            changeset
          end
        else
          changeset
        end
    end)
  end

  defp parse_map_param(param = %{}) do
    param
    |> Enum.sort_by(fn {idx, _} -> idx end)
    |> Map.new(fn {_, %{"key" => key, "value" => value}} -> {key, value} end)
  end

  defp parse_map_param(param), do: param

  @doc """
  Builds the base `Ecto.Query` used to list and look up records of `resource`.

  When the resource configures `query_with`, that function is invoked with the
  `resource` and `search` term and its result is used as-is. Otherwise the
  resource's schema is queried directly; a non-empty `search` string is applied
  across the resource's fields, supporting both `term` (all fields) and
  `field:term` (single field) syntax.
  """
  def query(resource, search, config) do
    resource
    |> fetch_config(:query_with, config)
    |> case do
      nil ->
        resource.__live_admin_config__()
        |> Keyword.fetch!(:schema)
        |> then(fn query ->
          case search do
            q when not is_nil(q) and byte_size(q) > 0 ->
              apply_search(query, q, fields(resource, config))

            _ ->
              query
          end
        end)

      {m, f} ->
        apply(m, f, [resource, search])

      f when is_atom(f) ->
        apply(resource, f, [search])
    end
  end

  @doc """
  Renders the value of `field` on `record` for display.

  When the resource configures `render_with`, that function receives the
  `record`, `field`, and current `session` and returns the content to display.
  Otherwise the raw value is formatted by `render/2` based on its `type`.
  """
  def render(record, field, type, resource, config, session) do
    resource
    |> LiveAdmin.fetch_config(:render_with, config)
    |> case do
      nil -> record |> Map.fetch!(field) |> render(type)
      {m, f} -> apply(m, f, [record, field, session])
      f when is_atom(f) -> apply(resource, f, [record, field, session])
    end
  end

  @doc """
  Formats a raw `value` for display according to its Ecto `type`.

  Handles the common built-in types (dates and times via `Calendar.strftime/2`,
  maps and embeds via `inspect/2`, arrays element-wise) and falls back to an
  HTML-safe rendering for everything else. `nil` renders as an empty string.
  """
  def render(nil, _), do: ""
  def render(val, {_, {Ecto.Embedded, _}}), do: inspect(val, pretty: true)
  def render(val, :map), do: inspect(val, pretty: true)
  def render(val, :date), do: Calendar.strftime(val, "%x")
  def render(val, dt) when dt in [DateTime, NaiveDateTime], do: Calendar.strftime(val, "%c")
  def render(val, :string), do: val
  def render(val, {:array, inner_type}), do: Enum.map_join(val, ", ", &render(&1, inner_type))
  def render(val, _), do: safe_render(val)
end
