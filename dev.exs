Logger.configure(level: :debug)

pg_url = System.get_env("PG_URL") || "postgres:postgres@127.0.0.1"

Application.put_env(:live_admin, Demo.Repo,
  url: "ecto://#{pg_url}/phx_admin_dev"
)

defmodule Demo.Repo do
  use Ecto.Repo, otp_app: :live_admin, adapter: Ecto.Adapters.Postgres
end

_ = Ecto.Adapters.Postgres.storage_up(Demo.Repo.config())

Application.put_env(:live_admin, DemoWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Hu4qQN3iKzTV4fJxhorPQlA/osH9fAMtbtjVS58PFgfw3ja5Z18Q/WSNR9wP4OfW",
  live_view: [signing_salt: "hMegieSe"],
  http: [port: System.get_env("PORT") || 4000],
  debug_errors: true,
  check_origin: false,
  watchers: [
    npm: ["run", "watch", cd: "assets"],
    npx: [
      "tailwindcss",
      "--input=css/app.css",
      "--output=../dist/css/app.css",
      "--postcss",
      "--watch",
      cd: "assets"
    ]
  ],
  live_reload: [
    patterns: [
      ~r"dist/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/live_admin/components/.*(ex)$",
      ~r"lib/live_admin/templates/.*/.*(ex)$",
      ~r"lib/live_admin/.*(ex)$"
    ]
  ],
  pubsub_server: Demo.PubSub
)

Application.put_env(:live_admin, :ecto_repo, Demo.Repo)
Application.put_env(:live_admin, :prefix_options, ["public", "this-is-a-fake-schema-with-a-really-long-name", "alt"])
Application.put_env(:live_admin, :immutable_fields, [:inserted_at])

defmodule DemoWeb.PageController do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, :index) do
    content(conn, """
    <h2>LiveAdmin Dev</h2>
    <a href="/admin">Open Admin</a>
    """)
  end

  defp content(conn, content) do
    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, "<!doctype html><html><body>#{content}</body></html>")
  end
end

defmodule Demo.Accounts.User.Settings do
  use Ecto.Schema

  embedded_schema do
    field :some_option, :string
  end
end

defmodule Demo.Accounts.User do
  use Ecto.Schema

  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :active, :boolean
    field :birth_date, :date
    field :stars_count, :integer
    field :private_data, :map
    field :password, :string
    field :status, Ecto.Enum, values: [:active, :suspended]
    field :tags, {:array, :string}, default: []
    field :roles, {:array, Ecto.Enum}, values: [:admin, :staff]

    embeds_one :settings, Demo.Accounts.User.Settings, on_replace: :delete

    has_many :posts, Demo.Posts.Post

    timestamps(updated_at: false)
  end

  def create(params, meta) do
    %__MODULE__{}
    |> cast(params, [:name, :stars_count, :roles])
    |> validate_number(:stars_count, greater_than_or_equal_to: 0)
    |> Demo.Repo.insert(prefix: meta[:__prefix__])
  end

  def validate(changeset, _meta) do
    Ecto.Changeset.validate_required(changeset, [:name])
  end

  def deactivate(user, _) do
    user
    |> Ecto.Changeset.change(active: false)
    |> Demo.Repo.update()
    |> case do
      {:ok, _} -> {:ok, "deactivated!"}
      error -> error
    end
  end

  def regenerate_passwords(_) do
    __MODULE__
    |> Demo.Repo.all()
    |> Enum.each(fn user ->
      user
      |> Ecto.Changeset.change(password: :crypto.strong_rand_bytes(16) |> Base.encode16())
      |> Demo.Repo.update()
    end)

    {:ok, "updated"}
  end
end

defmodule Demo.Posts.Post do
  use Ecto.Schema

  import Ecto.Changeset

  schema "posts" do
    field :body, :string

    belongs_to :user, Demo.Accounts.User
    belongs_to :disabled_user, Demo.Accounts.User

    timestamps(updated_at: false)
  end

  def fail(_) do
    {:error, "failed"}
  end
end

defmodule Demo.Populator do
  import Ecto.Query

  alias Demo.Repo

  def reset do
    teardown()
    run()
  end

  def run do
    Enum.each(1..100, fn _ ->
      %Demo.Accounts.User{
        name: Faker.Person.name(),
        settings: %{},
        active: true,
        birth_date: ~D[1999-12-31],
        stars_count: Enum.random(0..100),
        private_data: %{},
        password: :crypto.strong_rand_bytes(16) |> Base.encode16(),
        posts: [
          %Demo.Posts.Post{
            body: Faker.Lorem.paragraphs() |> Enum.join("\n\n"),
            disabled_user: get_user_if(:rand.uniform(2) == 1)
          }
        ]
      }
      |> Demo.Repo.insert!()
    end)
  end

  defp teardown do
    Repo.delete_all(Demo.Accounts.User)
    Repo.delete_all(Demo.Posts.Post)
  end

  defp get_user_if(true), do: from(Demo.Accounts.User, order_by: fragment("RANDOM()"), limit: 1) |> Demo.Repo.one()
  defp get_user_if(false), do: nil
end

defmodule DemoWeb.Router do
  use Phoenix.Router
  import LiveAdmin.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :fetch_session
  end

  scope "/" do
    pipe_through :browser
    get "/", DemoWeb.PageController, :index

    live_admin "/admin", resources: [
      {Demo.Accounts.User,
        hidden_fields: [:private_data],
        immutable_fields: [:password, :inserted_at],
        create_with: {Demo.Accounts.User, :create, []},
        validate_with: {Demo.Accounts.User, :validate, []},
        components: [
          new: {LiveAdmin.Components.Container, :render_new, []},
          edit: {LiveAdmin.Components.Container, :render_edit, []}
        ],
        label_with: :name,
        actions: [:deactivate],
        tasks: [:regenerate_passwords]
      },
      {Demo.Posts.Post, immutable_fields: [:disabled_user_id], tasks: [:fail]}
    ]
  end
end

defmodule DemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :live_admin

  socket "/live", Phoenix.LiveView.Socket
  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader

  plug Plug.Session,
    store: :cookie,
    key: "_live_view_key",
    signing_salt: "/VEDsdfsffMnp5"

  plug DemoWeb.Router
end

Application.put_env(:phoenix, :serve_endpoints, true)

Application.ensure_all_started(:os_mon)

Task.async(fn ->
  children = [Demo.Repo, DemoWeb.Endpoint, {Phoenix.PubSub, name: Demo.PubSub, adapter: Phoenix.PubSub.PG2}]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

  Demo.Populator.reset()

  Process.sleep(:infinity)
end)
|> Task.await(:infinity)
