defmodule Phoenix.LiveAdmin.Resource do
  import Phoenix.LiveAdmin, only: [get_config: 2, get_config: 3]
  import Phoenix.LiveAdmin.Components.Resource, only: [repo: 0, fields: 2]

  alias Ecto.Changeset

  def put_change(changeset, field, value) do
    Changeset.put_change(changeset, field, value)
  end

  def change(record, config, params \\ %{})

  def change(record, config, params) when is_struct(record) do
    build_changeset(record, config, params)
  end

  def change(resource, config, params) do
    resource
    |> struct(%{})
    |> build_changeset(config, params)
  end

  def create(resource, config, params, session) do
    config
    |> get_config(:create_with, :default)
    |> case do
      :default ->
        resource
        |> change(config, params)
        |> repo().insert(prefix: session[:__prefix__])

      {mod, func_name, args} ->
        apply(mod, func_name, [params, session] ++ args)
    end
  end

  def update(record, config, params, session) do
    config
    |> get_config(:update_with, :default)
    |> case do
      :default ->
        record
        |> change(config, params)
        |> repo().update()

      {mod, func_name, args} ->
        apply(mod, func_name, [record, params, session] ++ args)
    end
  end

  def validate(changeset, config, session) do
    config
    |> get_config(:validate_with)
    |> case do
      nil -> changeset
      {mod, func_name, args} -> apply(mod, func_name, [changeset, session] ++ args)
    end
  end

  defp build_changeset(record = %resource{}, config, params) do
    fields = fields(resource, config)

    {primitives, embeds} =
      Enum.split_with(fields, fn
        {_, {_, Ecto.Embedded, _}, _} -> false
        _ -> true
      end)

    castable_fields =
      Enum.flat_map(primitives, fn {field, _, opts} ->
        if Keyword.get(opts, :immutable, false), do: [], else: [field]
      end)

    changeset = Changeset.cast(record, params, castable_fields)

    Enum.reduce(embeds, changeset, fn {field, {_, Ecto.Embedded, _}, _}, changeset ->
      Changeset.cast_embed(changeset, field,
        with: fn embed, params ->
          build_changeset(embed, %{}, params)
        end
      )
    end)
  end
end
