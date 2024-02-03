defmodule Demo.Accounts.User do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :name, :string
    field :email, :string
    field :active, :boolean
    field :birth_date, :date
    field :stars_count, :integer
    field :private_data, :map
    field :encrypted_password, :string
    field :status, Ecto.Enum, values: [:active, :suspended]
    field :roles, {:array, Ecto.Enum}, values: [:admin, :staff]
    field :rating, :float

    field :password, :string, virtual: true

    embeds_one :settings, Demo.Accounts.User.Settings, on_replace: :delete

    has_many :posts, Demo.Posts.Post

    timestamps(updated_at: false)
  end
end

defmodule Demo.Accounts.User.Settings do
  use Ecto.Schema

  embedded_schema do
    field :some_option, :string

    embeds_many :configs, __MODULE__.Config, on_replace: :delete
  end
end

defmodule Demo.Accounts.User.Settings.Config do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :key, :string
    field :val, :string

    field :good, :boolean
    field :legal, :boolean
  end
end

defmodule Demo.Accounts.User.Profile do
  use Ecto.Schema
  use LiveAdmin.Resource, create_with: false

  schema "user_profiles" do
    belongs_to :user, Demo.Accounts.User, type: :binary_id
  end
end
