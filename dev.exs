Logger.configure(level: :debug)

pg_url = System.get_env("PG_URL") || "postgres:postgres@127.0.0.1"

Application.put_env(:phoenix_live_admin, Demo.Repo,
  url: "ecto://#{pg_url}/phx_admin_dev"
)

defmodule Demo.Repo do
  use Ecto.Repo, otp_app: :phoenix_live_admin, adapter: Ecto.Adapters.Postgres
end

_ = Ecto.Adapters.Postgres.storage_up(Demo.Repo.config())

Application.put_env(:phoenix_live_admin, DemoWeb.Endpoint,
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
      ~r"lib/phoenix/live_admin/components/.*(ex)$",
      ~r"lib/phoenix/live_admin/templates/.*/.*(ex)$"
    ]
  ],
  pubsub_server: Demo.PubSub
)

defmodule DemoWeb.PageController do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, :index) do
    content(conn, """
    <h2>Phoenix LiveAdmin Dev</h2>
    <a href="/admin">Open Admin</a>
    """)
  end

  defp content(conn, content) do
    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, "<!doctype html><html><body>#{content}</body></html>")
  end
end

defmodule DemoWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveAdmin.Router

  pipeline :browser do
    plug :fetch_session
  end

  scope "/" do
    pipe_through :browser
    get "/", DemoWeb.PageController, :index

    live_admin "/admin"
  end
end

defmodule DemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_live_admin

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

  Process.sleep(:infinity)
end)
|> Task.await(:infinity)
