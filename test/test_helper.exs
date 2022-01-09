pg_url = System.get_env("PG_URL") || "postgres:postgres@127.0.0.1"

Application.put_env(:phoenix_live_admin, Phoenix.LiveAdminTest.Repo,
  url: "ecto://#{pg_url}/phx_admin_dev"
)

defmodule Phoenix.LiveAdminTest.Repo do
  use Ecto.Repo, otp_app: :phoenix_live_admin, adapter: Ecto.Adapters.Postgres
end

_ = Ecto.Adapters.Postgres.storage_up(Phoenix.LiveAdminTest.Repo.config())

Application.put_env(:phoenix_live_admin, Phoenix.LiveAdminTest.Endpoint,
  url: [host: "localhost", port: 4000],
  secret_key_base: "Hu4qQN3iKzTV4fJxhorPQlA/osH9fAMtbtjVS58PFgfw3ja5Z18Q/WSNR9wP4OfW",
  live_view: [signing_salt: "hMegieSe"],
  render_errors: [view: Phoenix.LiveAdminTest.ErrorView],
  check_origin: false,
  pubsub_server: Phoenix.LiveAdminTest.PubSub
)

defmodule Phoenix.LiveAdminTest.ErrorView do
  use Phoenix.View, root: "test/templates"

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule Phoenix.LiveAdminTest.Router do
  use Phoenix.Router
  import Phoenix.LiveAdmin.Router

  pipeline :browser do
    plug(:fetch_session)
  end

  scope "/" do
    pipe_through(:browser)

    live_admin("/", resources: [Phoenix.LiveAdminTest.User])
  end
end

defmodule Phoenix.LiveAdminTest.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_live_admin

  plug(Plug.Session,
    store: :cookie,
    key: "_live_view_key",
    signing_salt: "/VEDsdfsffMnp5"
  )

  plug(Phoenix.LiveAdminTest.Router)
end

defmodule Phoenix.LiveAdminTest.User do
  use Ecto.Schema

  schema "users" do
    field :name, :string

    embeds_one :settings, Phoenix.LiveAdminTest.Settings
  end
end

defmodule Phoenix.LiveAdminTest.Settings do
  use Ecto.Schema

  embedded_schema do
    field :some_option, :string
  end
end

Application.ensure_all_started(:os_mon)

Application.put_env(:phoenix_live_admin, :ecto_repo, Phoenix.LiveAdminTest.Repo)

Supervisor.start_link(
  [
    Phoenix.LiveAdminTest.Repo,
    {Phoenix.PubSub, name: Phoenix.LiveAdminTest.PubSub, adapter: Phoenix.PubSub.PG2},
    Phoenix.LiveAdminTest.Endpoint
  ],
  strategy: :one_for_one
)

Phoenix.LiveAdminTest.Repo.delete_all(Phoenix.LiveAdminTest.User)

ExUnit.start(exclude: :integration)
