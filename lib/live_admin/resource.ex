defmodule LiveAdmin.Resource do
  @moduledoc """
  API for managing Ecto schemas and their individual record instances used internally by LiveAdmin.

  > #### `use LiveAdmin.Resource` {: .info}
  > This is required in any module that should act as a LiveAdmin Resource.
  > If the module is not an Ecto schema, then the `:schema` option must be passed.
  > Using this module will create a __live_admin_config__ module variable and a function
  > to query it, __live_admin_config__/0.
  """

  import Ecto.Query
  import LiveAdmin, only: [record_label: 3, parent_associations: 1]

  alias Ecto.Changeset
  alias PhoenixHTMLHelpers.Tag

  @doc """
  Configure a module to act as a LiveAdmin resource

  In addition to global options, also accepts `schema` in case the resource
  is not also an Ecto schema.
  """
  defmacro __using__(opts) do
    opts_schema =
      LiveAdmin.base_configs_schema() ++
        [
          schema: [type: :atom, default: __CALLER__.module],
          preload: [type: {:or, [:keyword_list, nil]}, default: nil]
        ]

    quote bind_quoted: [opts: opts, opts_schema: opts_schema] do
      opts = NimbleOptions.validate!(opts, opts_schema)

      @__live_admin_config__ opts

      def __live_admin_config__, do: @__live_admin_config__
    end
  end

  def render(record, field, resource, assoc_resource, session, config) do
    resource
    |> LiveAdmin.fetch_config(:render_with, config)
    |> case do
      nil ->
        if assoc_resource do
          record_label(
            Map.fetch!(
              record,
              resource.__live_admin_config__()
              |> Keyword.fetch!(:schema)
              |> get_assoc_name!(field)
            ),
            elem(assoc_resource, 1),
            config
          )
        else
          record
          |> Map.fetch!(field)
          |> render_field()
        end

      {m, f} ->
        apply(m, f, [record, field, session])

      f when is_atom(f) ->
        apply(resource, f, [record, field, session])
    end
  end

  def all(keys, resource, prefix, repo) do
    key = LiveAdmin.primary_key!(resource)

    resource.__live_admin_config__()
    |> Keyword.fetch!(:schema)
    |> where([s], field(s, ^key) in ^keys)
    |> repo.all(prefix: prefix)
  end

  def find!(key, resource, prefix, repo) do
    find(key, resource, prefix, repo) ||
      raise(Ecto.NoResultsError,
        queryable: Keyword.fetch!(resource.__live_admin_config__(), :schema)
      )
  end

  def find(key, resource, prefix, repo) do
    resource.__live_admin_config__()
    |> Keyword.fetch!(:schema)
    |> preload(^preloads(resource))
    |> repo.get(key, prefix: prefix)
  end

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

  def list(resource, opts, session, repo, config) do
    resource
    |> LiveAdmin.fetch_config(:list_with, config)
    |> case do
      nil ->
        build_list(resource, opts, repo, config)

      {mod, func_name} ->
        apply(mod, func_name, [resource, opts, session])

      name when is_atom(name) ->
        apply(resource, name, [opts, session])
    end
  end

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

  def fields(resource, config) do
    schema = Keyword.fetch!(resource.__live_admin_config__(), :schema)

    Enum.flat_map(schema.__schema__(:fields), fn field_name ->
      resource
      |> LiveAdmin.fetch_config(:hidden_fields, config)
      |> Enum.member?(field_name)
      |> case do
        false ->
          [
            {field_name, schema.__schema__(:type, field_name),
             [
               immutable:
                 resource
                 |> LiveAdmin.fetch_config(:immutable_fields, config)
                 |> Enum.member?(field_name)
             ]}
          ]

        true ->
          []
      end
    end)
  end

  defp build_list(resource, opts, repo, config) do
    opts =
      opts
      |> Enum.into(%{})
      |> Map.put_new(:page, 1)
      |> Map.put_new(:sort_dir, :asc)
      |> Map.put_new(:sort_attr, LiveAdmin.primary_key!(resource))

    query =
      resource.__live_admin_config__()
      |> Keyword.fetch!(:schema)
      |> limit(10)
      |> offset(^((opts[:page] - 1) * 10))
      |> order_by(^[{opts[:sort_dir], opts[:sort_attr]}])
      |> preload(^preloads(resource))

    query =
      opts
      |> Enum.reduce(query, fn
        {:search, q}, query when byte_size(q) > 0 ->
          apply_search(query, q, fields(resource, config))

        _, query ->
          query
      end)

    {
      repo.all(query, prefix: opts[:prefix]),
      repo.aggregate(
        query |> exclude(:limit) |> exclude(:offset),
        :count,
        prefix: opts[:prefix]
      )
    }
  end

  defp apply_search(query, q, fields) do
    q
    |> String.split(~r{[^\s]*:}, include_captures: true, trim: true)
    |> case do
      [q] ->
        matcher = if String.contains?(q, "%"), do: q, else: "%#{q}%"

        Enum.reduce(fields, query, fn {field_name, _, _}, query ->
          or_where(
            query,
            [r],
            like(
              fragment("LOWER(CAST(? AS text))", field(r, ^field_name)),
              ^String.downcase(matcher)
            )
          )
        end)

      field_queries ->
        field_queries
        |> Enum.map(&String.trim/1)
        |> Enum.chunk_every(2)
        |> Enum.reduce(query, fn
          [field_key, q], query ->
            fields
            |> Enum.find_value(fn {field_name, _, _} ->
              if "#{field_name}:" == field_key, do: field_name
            end)
            |> case do
              nil ->
                query

              field_name ->
                or_where(
                  query,
                  [r],
                  ilike(fragment("CAST(? AS text)", field(r, ^field_name)), ^"%#{q}%")
                )
            end

          _, query ->
            query
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
      {field_name, {_, Ecto.Embedded, %{cardinality: :many}}, _}, changeset ->
        Changeset.cast_embed(changeset, field_name,
          with: fn embed, params -> build_changeset(embed, :embed, params, config) end,
          sort_param: LiveAdmin.View.sort_param_name(field_name),
          drop_param: LiveAdmin.View.drop_param_name(field_name)
        )

      {field_name, {_, Ecto.Embedded, %{cardinality: :one}}, _}, changeset ->
        if Map.get(params, to_string(field_name)) == "" do
          Changeset.put_change(changeset, field_name, nil)
        else
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

  defp preloads(resource) do
    resource.__live_admin_config__()
    |> Keyword.fetch!(:preload)
    |> case do
      nil ->
        resource.__live_admin_config__()
        |> Keyword.fetch!(:schema)
        |> parent_associations()
        |> Enum.map(& &1.field)

      {m, f, []} ->
        apply(m, f, [resource])

      preloads when is_list(preloads) ->
        preloads
    end
  end

  defp get_assoc_name!(schema, fk) do
    Enum.find(schema.__schema__(:associations), fn assoc_name ->
      fk == schema.__schema__(:association, assoc_name).owner_key
    end)
  end

  defp render_field(val = %{}), do: Tag.content_tag(:pre, inspect(val, pretty: true))

  defp render_field(val) when is_list(val),
    do: Enum.map(val, &Tag.content_tag(:pre, inspect(&1, pretty: true)))

  defp render_field(val) when is_binary(val), do: val
  defp render_field(val), do: inspect(val)
end
