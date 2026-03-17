Logger.configure(level: :debug)

pg_url = System.get_env("PG_URL") || "postgres:postgres@127.0.0.1"

Application.put_env(:live_admin, Demo.Repo, url: "ecto://#{pg_url}/phx_admin_dev")

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
      "postcss",
      "css/app.css",
      "--output=../dist/css/app.css",
      "--watch",
      cd: "assets"
    ],
    npx: [
      "postcss",
      "css/default_overrides.css",
      "--output=../dist/css/default_overrides.css",
      "--watch",
      cd: "assets"
    ],
    watchers: [
      node: ["esbuild.js", "--watch", cd: Path.expand("../assets", __DIR__)]
    ]
  ],
  live_reload: [
    patterns: [
      ~r"dist/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/live_admin/components/.*(ex)$",
      ~r"lib/live_admin/templates/.*/.*(ex)$",
      ~r"lib/live_admin/.*(ex)$",
      ~r"dev/.*(ex)$"
    ]
  ],
  pubsub_server: Demo.PubSub
)

Application.put_env(:live_admin, :ecto_repo, Demo.Repo)
Application.put_env(:live_admin, :immutable_fields, [:inserted_at])
Application.put_env(:live_admin, :css_overrides, {DemoWeb.Renderer, :render_css, []})
Application.put_env(:live_admin, :gettext_backend, Demo.Gettext)

defmodule DemoWeb.Router do
  use Phoenix.Router

  import LiveAdmin.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:fetch_session)

    plug(:user_id_stub)
  end

  scope "/" do
    pipe_through(:browser)
    get("/", DemoWeb.PageController, :index)

    live_admin "/admin", title: "DevAdmin" do
      admin_resource("/users/profiles", Demo.Accounts.User.Profile)
      admin_resource("/security-settings", Demo.Accounts.SecuritySetting)
      admin_resource("/users", DemoWeb.UserAdmin)
      live("/extra", DemoWeb.Extra, :index, as: :extra)
    end

    live_admin "/posts-admin", components: [home: DemoWeb.PostsAdmin.Home] do
      admin_resource("/posts", Demo.Posts.Post)
      admin_resource("/users", DemoWeb.UserAdmin)
    end
  end

  defp user_id_stub(conn, _) do
    Plug.Conn.assign(conn, :user_id, 1)
  end
end

defmodule DemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :live_admin

  socket("/live", Phoenix.LiveView.Socket)
  socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)

  plug(Phoenix.LiveReloader)
  plug(Phoenix.CodeReloader)

  plug(Plug.Session,
    store: :cookie,
    key: "_live_view_key",
    signing_salt: "/VEDsdfsffMnp5"
  )

  plug(DemoWeb.Router)
end

Application.put_env(:phoenix, :serve_endpoints, true)

Application.ensure_all_started(:os_mon)

Task.async(fn ->
  children = [
    Demo.Repo,
    DemoWeb.Endpoint,
    {Phoenix.PubSub, name: Demo.PubSub, adapter: Phoenix.PubSub.PG2}
  ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

  Demo.Populator.reset()

  Process.sleep(:infinity)
end)
|> Task.await(:infinity)
