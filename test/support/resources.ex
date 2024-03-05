defmodule LiveAdminTest.User do
  use Ecto.Schema

  use LiveAdmin.Resource,
    immutable_fields: [:encrypted_password],
    actions: [:user_action]

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field(:name, :string)
    field(:encrypted_password, :string)

    embeds_one(:settings, LiveAdminTest.Settings)
  end

  def user_action(%__MODULE__{}, %{}), do: {:ok, "worked"}
end

defmodule LiveAdminTest.PostResource do
  use LiveAdmin.Resource,
    schema: LiveAdminTest.Post,
    actions: [:run_action],
    label_with: {__MODULE__, :label}

  def run_action(_, _), do: {:ok, "worked"}

  def label(post), do: post.post_id
end

defmodule LiveAdminTest.Post do
  use Ecto.Schema

  @primary_key {:post_id, :id, autogenerate: true}
  @derive {Phoenix.Param, key: :post_id}
  schema "posts" do
    field(:title, :string)
    field(:tags, {:array, :string}, default: ["test"])

    belongs_to(:user, LiveAdminTest.User, type: :binary_id)

    embeds_many(:previous_versions, __MODULE__.Version, on_replace: :delete)
  end
end

defmodule LiveAdminTest.Settings do
  use Ecto.Schema

  embedded_schema do
    field(:some_option, :string)
    field(:metadata, :map)
  end
end

defmodule LiveAdminTest.Post.Version do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field(:body, :string)
    field(:tags, {:array, :string})

    timestamps(updated_at: false)
  end
end
