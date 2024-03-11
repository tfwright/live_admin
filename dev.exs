Logger.configure(level: :debug)

pg_url = System.get_env("PG_URL") || "postgres:postgres@127.0.0.1"

Application.put_env(:live_admin, Demo.Repo,
  url: "ecto://#{pg_url}/phx_admin_dev"
)

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
    ],
    npx: [
      "tailwindcss",
      "--input=css/default_overrides.css",
      "--output=../dist/css/default_overrides.css",
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
Application.put_env(:live_admin, :immutable_fields, [:inserted_at])
Application.put_env(:live_admin, :css_overrides, {DemoWeb.Renderer, :render_css, []})
Application.put_env(:live_admin, :gettext_backend, Demo.Gettext)

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
        email: "#{Ecto.UUID.generate()}@example.com",
        settings: %{},
        active: true,
        birth_date: ~D[1999-12-31],
        stars_count: Enum.random(0..100),
        private_data: %{},
        encrypted_password: :crypto.strong_rand_bytes(16) |> Base.encode16(),
        posts: [
          %Demo.Posts.Post{
            title: Faker.Lorem.paragraph(1) |> String.slice(0..9),
            categories: Ecto.Enum.values(Demo.Posts.Post, :categories) |> Enum.take(Enum.random(0..2)),
            tags: Faker.Lorem.words(Enum.random(0..5)),
            body: Faker.Lorem.paragraphs() |> Enum.join("\n\n"),
            disabled_user: get_user_if(:rand.uniform(2) == 1),
            previous_versions: [%Demo.Posts.Post.Version{body: Faker.Lorem.paragraphs() |> Enum.join("\n\n")}]
          }
        ]
      }
      |> Demo.Repo.insert!()
    end)
  end

  defp teardown do
    Repo.delete_all(Demo.Accounts.User)
    Repo.delete_all(Demo.Posts.Post)
    Repo.delete_all(Demo.Accounts.User.Profile)
  end

  defp get_user_if(true), do: from(Demo.Accounts.User, order_by: fragment("RANDOM()"), limit: 1) |> Demo.Repo.one()
  defp get_user_if(false), do: nil
end

defmodule DemoWeb.CreateUserForm do
  use Phoenix.LiveComponent
  use PhoenixHTMLHelpers

  import Phoenix.HTML
  import Phoenix.HTML.Form

  import LiveAdmin, only: [route_with_params: 2]
  import LiveAdmin.ErrorHelpers

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:changeset, Ecto.Changeset.change(%Demo.Accounts.User{}))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :enabled, Enum.empty?(assigns.changeset.errors))

    ~H"""
    <div>
      <.form
        :let={f}
        for={@changeset}
        as={:params}
        phx-change="validate"
        phx-submit="create"
        phx-target={@myself}
        class="resource__form"
      >

        <div class={"field__group"}>
          <%= label(f, :name, class: "field__label") %>
          <%= textarea(f, :name, rows: 1, class: "field__text") %>
          <%= error_tag(f, :name) %>
        </div>

        <div class={"field__group"}>
          <%= label(f, :email, class: "field__label") %>
          <%= textarea(f, :email, rows: 1, class: "field__text") %>
          <%= error_tag(f, :email) %>
        </div>

        <div class={"field__group"}>
          <%= label(f, :password, class: "field__label") %>
          <%= password_input(f, :password, class: "field__text", value: input_value(f, :password)) %>
          <%= error_tag(f, :password) %>
        </div>

        <div class={"field__group"}>
          <%= label(f, :password_confirmation, class: "field__label") %>
          <%= password_input(f, :password_confirmation, class: "field__text") %>
          <%= error_tag(f, :password_confirmation) %>
        </div>

        <div class="form__actions">
        <%= submit("Save",
          class: "resource__action#{if !@enabled, do: "--disabled", else: "--btn"}",
          disabled: !@enabled
          ) %>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event(
        "validate",
        %{"params" => params},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    changeset =
      changeset.data
      |> Ecto.Changeset.cast(params, [:name, :email, :password])
      |> Ecto.Changeset.validate_required([:name, :email, :password])
      |> Ecto.Changeset.validate_confirmation(:password)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("create", %{"params" => params}, socket = %{assigns: assigns}) do
    socket =
      %Demo.Accounts.User{}
      |> Ecto.Changeset.cast(params, [:name, :email, :stars_count, :roles])
      |> Ecto.Changeset.validate_required([:name, :email])
      |> Ecto.Changeset.unique_constraint(:email)
      |> Demo.Repo.insert(prefix: assigns.prefix)
      |> case do
        {:ok, _} -> push_redirect(socket, to: route_with_params(assigns, params: [prefix: assigns.prefix]))
        {:error, changeset} -> assign(socket, changeset: changeset)
      end

    {:noreply, socket}
  end
end

defmodule DemoWeb.PostsAdmin.Home do
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-full items-center justify-center">
      <div class="w-1/2">
        This is only for managing posts
      </div>
    </div>
    """
  end
end

defmodule DemoWeb.Extra do
  use Phoenix.LiveView

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-full items-center justify-center">
      <div class="w-1/2">
        This is an extra page
      </div>
    </div>
    """
  end
end

defmodule DemoWeb.Router do
  use Phoenix.Router

  import LiveAdmin.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :fetch_session

    plug :user_id_stub
  end
  scope "/" do
    pipe_through :browser
    get "/", DemoWeb.PageController, :index

    live_admin "/admin", title: "DevAdmin" do
      admin_resource "/users/profiles", Demo.Accounts.User.Profile
      admin_resource "/users", DemoWeb.UserAdmin
      live "/extra", DemoWeb.Extra, :index, as: :extra
    end

    live_admin "/posts-admin", components: [home: DemoWeb.PostsAdmin.Home] do
      admin_resource "/posts", Demo.Posts.Post
      admin_resource "/users", DemoWeb.UserAdmin
    end
  end

  defp user_id_stub(conn, _) do
    Plug.Conn.assign(conn, :user_id, 1)
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
