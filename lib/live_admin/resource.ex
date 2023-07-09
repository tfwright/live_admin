defmodule LiveAdmin.Resource do
  @moduledoc """
  API for managing Ecto schemas and their individual record instances used internally by LiveAdmin.

  > #### `use LiveAdmin.Resource` {: .info}
  > This is required in any module that should act as a LiveAdmin Resource.
  > If the module is not an Ecto schema, then the `:schema` option must be passed.
  > Using this module will create a __live_admin_config__ module variable and 2 functions
  > to query it, __live_admin_config__/0 and __live_admin_config__/1. The former returns the entire
  > config while the latter will return a key if it exists, otherwise it will fallback
  > to either a global config for that key, or the key's default value.

  To customize UI behavior, the following options may also be used:

  * `title_with` - a binary, or MFA that returns a binary, used to identify the resource
  * `label_with` - a binary, or MFA that returns a binary, used to identify records
  * `list_with` - an atom or MFA that identifies the function that implements listing the resource
  * `create_with` - an atom or MFA that identifies the function that implements creating the resource
  * `update_with` - an atom or MFA that identifies the function that implements updating a record
  * `delete_with` - an atom or MFA that identifies the function that implements deleting a record
  * `validate_with` - an atom or MFA that identifies the function that implements validating a changed record
  * `render_with` - an atom or MFA that identifies the function that implements table field rendering logic
  * `hidden_fields` - a list of fields that should not be displayed in the UI
  * `immutable_fields` - a list of fields that should not be editable in forms
  * `actions` - list of atoms or MFAs that identify a function that operates on a record
  * `tasks` - list atoms or MFAs that identify a function that operates on a resource
  * `components` - keyword list of component module overrides for specific views (`:list`, `:new`, `:edit`, `:home`, `:nav`, `:session`)
  * `ecto_repo` - Ecto repo to use when building queries for this resource
  """

  import Ecto.Query
  import LiveAdmin, only: [parent_associations: 1]

  alias Ecto.Changeset

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @__live_admin_config__ Keyword.put_new(opts, :schema, __MODULE__)

      def __live_admin_config__, do: @__live_admin_config__

      def __live_admin_config__(key),
        do:
          Keyword.get(@__live_admin_config__, key, Application.get_env(:live_admin, key)) ||
            LiveAdmin.Resource.default_config_value(key)
    end
  end

  def find!(id, resource, prefix, repo),
    do: repo.get!(resource.__live_admin_config__(:schema), id, prefix: prefix)

  def find(id, resource, prefix, repo),
    do: repo.get(resource.__live_admin_config__(:schema), id, prefix: prefix)

  def delete(record, resource, session, repo) do
    :delete_with
    |> resource.__live_admin_config__()
    |> case do
      nil ->
        repo.delete(record)

      {mod, func_name, args} ->
        apply(mod, func_name, [record, session] ++ args)
    end
  end

  def list(resource, opts, session, repo) do
    :list_with
    |> resource.__live_admin_config__()
    |> case do
      nil ->
        build_list(resource, opts, repo)

      {mod, func_name, args} ->
        apply(mod, func_name, [resource, opts, session] ++ args)
    end
  end

  def change(resource, record \\ nil, params \\ %{})

  def change(resource, record, params) when is_struct(record) do
    build_changeset(record, resource, params)
  end

  def change(resource, nil, params) do
    :schema
    |> resource.__live_admin_config__()
    |> struct(%{})
    |> build_changeset(resource, params)
  end

  def create(resource, params, session, repo) do
    :create_with
    |> resource.__live_admin_config__()
    |> case do
      nil ->
        resource
        |> change(nil, params)
        |> repo.insert(prefix: session.prefix)

      {mod, func_name, args} ->
        apply(mod, func_name, [params, session] ++ args)
    end
  end

  def update(record, resource, params, session) do
    :update_with
    |> resource.__live_admin_config__()
    |> case do
      nil ->
        resource
        |> change(record, params)
        |> resource.__live_admin_config__(:ecto_repo).update()

      {mod, func_name, args} ->
        apply(mod, func_name, [record, params, session] ++ args)
    end
  end

  def validate(changeset, resource, session) do
    :validate_with
    |> resource.__live_admin_config__()
    |> case do
      nil -> changeset
      {mod, func_name, args} -> apply(mod, func_name, [changeset, session] ++ args)
      atom -> apply(resource, atom, [changeset, session])
    end
    |> Map.put(:action, :validate)
  end

  def fields(resource) do
    schema = resource.__live_admin_config__(:schema)

    Enum.flat_map(schema.__schema__(:fields), fn field_name ->
      :hidden_fields
      |> resource.__live_admin_config__()
      |> Enum.member?(field_name)
      |> case do
        false ->
          [
            {field_name, schema.__schema__(:type, field_name),
             [
               immutable:
                 Enum.member?(resource.__live_admin_config__(:immutable_fields) || [], field_name)
             ]}
          ]

        true ->
          []
      end
    end)
  end

  def default_config_value(key) when key in [:actions, :tasks, :components, :hidden_fields],
    do: []

  def default_config_value(:render_with), do: {LiveAdmin.View, :render_field, []}

  def default_config_value(:label_with), do: :id

  def default_config_value(_), do: nil

  defp build_list(resource, opts, repo) do
    opts =
      opts
      |> Enum.into(%{})
      |> Map.put_new(:page, 1)
      |> Map.put_new(:sort_dir, :asc)
      |> Map.put_new(:sort_attr, :id)

    query =
      :schema
      |> resource.__live_admin_config__()
      |> limit(10)
      |> offset(^((opts[:page] - 1) * 10))
      |> order_by(^[{opts[:sort_dir], opts[:sort_attr]}])
      |> preload(^preloads(resource))

    query =
      opts
      |> Enum.reduce(query, fn
        {:search, q}, query when byte_size(q) > 0 ->
          apply_search(query, q, fields(resource))

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
        Enum.reduce(fields, query, fn {field_name, _, _}, query ->
          or_where(
            query,
            [r],
            ilike(fragment("CAST(? AS text)", field(r, ^field_name)), ^"%#{q}%")
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

  defp build_changeset(record = %schema{}, resource, params) do
    resource
    |> case do
      :embed ->
        Enum.map(schema.__schema__(:fields), fn field_name ->
          {field_name, schema.__schema__(:type, field_name), []}
        end)

      resource ->
        fields(resource)
    end
    |> Enum.reduce(Changeset.cast(record, params, []), fn
      {field_name, {_, Ecto.Embedded, meta}, _}, changeset ->
        if Map.get(params, to_string(field_name)) == "delete" do
          Changeset.put_embed(
            changeset,
            field_name,
            if(meta.cardinality == :many, do: [], else: nil)
          )
        else
          Changeset.cast_embed(changeset, field_name,
            with: fn embed, params -> build_changeset(embed, :embed, params) end
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
    :preload
    |> resource.__live_admin_config__()
    |> case do
      nil ->
        resource.__live_admin_config__(:schema)
        |> parent_associations()
        |> Enum.map(& &1.field)

      {m, f, a} ->
        apply(m, f, [resource | a])

      preloads when is_list(preloads) ->
        preloads
    end
  end
end
