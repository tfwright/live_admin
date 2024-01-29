defmodule Demo.Posts.Post do
  use Ecto.Schema
  use LiveAdmin.Resource,
    immutable_fields: [:disabled_user_id],
    tasks: [:fail],
    validate_with: :validate,
    update_with: :update,
    ecto_repo: Demo.Repo

  @primary_key {:post_id, :id, autogenerate: true}
  @derive {Phoenix.Param, key: :post_id}
  schema "posts" do
    field :title, :string
    field :body, :string
    field :tags, {:array, :string}, default: []
    field :categories, {:array, Ecto.Enum}, values: [:personal, :work]
    field :status, Ecto.Enum, values: [:draft, :archived, :live]
    field :metadata, :map

    embeds_many :previous_versions, __MODULE__.Version, on_replace: :delete

    belongs_to :user, Demo.Accounts.User, type: :binary_id
    belongs_to :disabled_user, Demo.Accounts.User, type: :binary_id

    timestamps(updated_at: false)
  end

  def fail(_) do
    {:error, "failed"}
  end

  def validate(changeset, _) do
    changeset
    |> Ecto.Changeset.validate_required([:title, :body, :user_id])
    |> Ecto.Changeset.validate_length(:title, max: 10, message: "cannot be longer than 10 characters")
  end

  def update(record, params, _) do
    record
    |> Ecto.Changeset.cast(params, [:title, :body, :user_id, :inserted_at, :tags, :categories])
    |> Ecto.Changeset.cast_embed(:previous_versions, with: fn version, params ->
      Ecto.Changeset.cast(version, params, [:body, :tags, :inserted_at])
    end)
    |> Ecto.Changeset.validate_required([:title, :body, :user_id, :inserted_at])
    |> Ecto.Changeset.validate_length(:title, max: 10, message: "cannot be longer than 10 characters")
    |> Ecto.Changeset.validate_change(:title, fn _, new_title ->
      if !String.contains?(new_title, record.title) do
        [title: "must contain original"]
      else
        []
      end
    end)
    |> Demo.Repo.update()
  end
end

defmodule Demo.Posts.Post.Version do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :body, :string
    field :tags, {:array, :string}

    timestamps(updated_at: false)
  end
end
