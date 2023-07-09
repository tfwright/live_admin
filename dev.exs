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
Application.put_env(:live_admin, :render_with, {DemoWeb.Renderer, :render_field, []})
Application.put_env(:live_admin, :css_overrides, {DemoWeb.Renderer, :render_css, []})
Application.put_env(:live_admin, :gettext_backend, Demo.Gettext)

defmodule DemoWeb.Renderer do
  use Phoenix.HTML

  def render_field(record, field, session) do
    record
    |> Map.fetch!(field)
    |> case do
      bool when is_boolean(bool) -> if bool, do: "Yes", else: "No"
      date = %Date{} -> Calendar.strftime(date, "%a, %B %d %Y")
      _ -> LiveAdmin.View.render_field(record, field, session)
    end
  end

  def render_css(%{metadata: %{"css_theme" => "dark"}}) do
    """
    body {
      background-color: #444;
      color: #fff;
    }

    .nav {
      background-color: #444;
    }

    .resource__action--btn {
      background-color: #aaa;
      border-color: #fff;
      color: #000;
    }

    .resource__action--btn:hover {
      background-color: #ccc;
      border-color: #iii;
    }

    .resource__menu--drop nav {
      color: #000;
      background-color: #ccc;
      border-color: #iii;
    }

    .resource__header {
      background-color: #bbb;
      color: #000
    }

    .nav a:hover {
      background-color: #ccc;
    }

    .toast__container--error {
      border-color: violet;
    }

    .toast__container--success {
      border-color: chartreuse;
    }
    """
  end

  def render_css(_) do
    __DIR__
    |> Path.join("dist/css/default_overrides.css")
    |> File.read!()
  end
end

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

defmodule Demo.Accounts.User.Profile do
  use Ecto.Schema
  use LiveAdmin.Resource, create_with: nil

  schema "user_profiles" do
    belongs_to :user, Demo.Accounts.User, type: :binary_id
  end
end

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

defmodule Demo.Posts.Post.Version do
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :body, :string
    field :status, {:array, Ecto.Enum}, values: [:draft, :archived, :live]

    timestamps(updated_at: false)
  end
end

defmodule Demo.Posts.Post do
  use Ecto.Schema
  use LiveAdmin.Resource,
    immutable_fields: [:disabled_user_id],
    tasks: [:fail],
    validate_with: :validate,
    update_with: :update,
    ecto_repo: Demo.Repo

  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :body, :string
    field :tags, {:array, :string}, default: []
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
    |> Ecto.Changeset.cast(params, [:title, :body, :user_id, :inserted_at])
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

defmodule DemoWeb.CreateUserForm do
  use Phoenix.LiveComponent
  use Phoenix.HTML

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

defmodule DemoWeb.UserAdmin do
  use LiveAdmin.Resource,
      schema: Demo.Accounts.User,
      hidden_fields: [:private_data],
      immutable_fields: [:encrypted_password, :inserted_at],
      components: [new: DemoWeb.CreateUserForm],
      label_with: :name,
      actions: [:deactivate],
      tasks: [:regenerate_passwords],
      render_with: :render_field

  def deactivate(user, _) do
    user
    |> Ecto.Changeset.change(active: false)
    |> Demo.Repo.update()
    |> case do
      {:ok, _} -> {:ok, "deactivated!"}
      error -> error
    end
  end

  def render_field(user, :email, _) do
    Phoenix.HTML.Link.link(user.email, to: "mailto:\"#{user.name}\"<#{user.email}>")
  end

  def render_field(record, field, session) do
    DemoWeb.Renderer.render_field(record, field, session)
  end

  def regenerate_passwords(_) do
    Demo.Accounts.User
    |> Demo.Repo.all()
    |> Enum.each(fn user ->
      user
      |> Ecto.Changeset.change(encrypted_password: :crypto.strong_rand_bytes(16) |> Base.encode16())
      |> Demo.Repo.update()
    end)

    {:ok, "updated"}
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
      admin_resource "/users", DemoWeb.UserAdmin
      admin_resource "/users/profiles", Demo.Accounts.User.Profile
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

defmodule Demo.Gettext do
  use Gettext, otp_app: :demo, priv: "priv/demo/gettext"

  def locales, do: ["en", "tr"]
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
