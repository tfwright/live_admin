pg_url = System.get_env("PG_URL") || "postgres:postgres@127.0.0.1"

Application.put_env(:live_admin, LiveAdminTest.Repo,
  url: "ecto://#{pg_url}/phx_admin_dev",
  pool: Ecto.Adapters.SQL.Sandbox
)

defmodule LiveAdminTest.Repo do
  use Ecto.Repo, otp_app: :live_admin, adapter: Ecto.Adapters.Postgres
end

_ = Ecto.Adapters.Postgres.storage_up(LiveAdminTest.Repo.config())

Application.put_env(:live_admin, LiveAdminTest.Endpoint,
  url: [host: "localhost", port: 4000],
  secret_key_base: "Hu4qQN3iKzTV4fJxhorPQlA/osH9fAMtbtjVS58PFgfw3ja5Z18Q/WSNR9wP4OfW",
  live_view: [signing_salt: "hMegieSe"],
  render_errors: [view: LiveAdminTest.ErrorView],
  check_origin: false,
  pubsub_server: LiveAdminTest.PubSub
)

defmodule LiveAdminTest.ErrorView do
  use Phoenix.View, root: "test/templates"

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule LiveAdminTest.Router do
  use Phoenix.Router
  import LiveAdmin.Router

  pipeline :browser do
    plug(:fetch_session)
  end

  scope "/" do
    pipe_through(:browser)

    live_admin("/",
      resources: [
        {
          LiveAdminTest.User,
          immutable_fields: [:encrypted_password], actions: [:run_action]
        },
        LiveAdminTest.Post
      ]
    )
  end
end

defmodule LiveAdminTest.Endpoint do
  use Phoenix.Endpoint, otp_app: :live_admin

  plug(Plug.Session,
    store: :cookie,
    key: "_live_view_key",
    signing_salt: "/VEDsdfsffMnp5"
  )

  plug(LiveAdminTest.Router)
end

defmodule LiveAdminTest.User do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field(:name, :string)
    field(:encrypted_password, :string)

    belongs_to(:other_resource, OtherResource)

    embeds_one(:settings, LiveAdminTest.Settings)
  end

  def run_action(%__MODULE__{}, %{}), do: {:ok, "worked"}
end

defmodule LiveAdminTest.Post do
  use Ecto.Schema

  schema "posts" do
    belongs_to(:user, LiveAdminTest.User, type: :binary_id)
  end
end

defmodule LiveAdminTest.Settings do
  use Ecto.Schema

  embedded_schema do
    field(:some_option, :string)
  end
end

Application.ensure_all_started(:os_mon)

Application.put_env(:live_admin, :ecto_repo, LiveAdminTest.Repo)

Supervisor.start_link(
  [
    LiveAdminTest.Repo,
    {Phoenix.PubSub, name: LiveAdminTest.PubSub, adapter: Phoenix.PubSub.PG2},
    LiveAdminTest.Endpoint
  ],
  strategy: :one_for_one
)

LiveAdminTest.Repo.delete_all(LiveAdminTest.User)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(LiveAdminTest.Repo, :manual)
