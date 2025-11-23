defmodule DemoWeb.UserAdmin do
  use LiveAdmin.Resource,
      schema: Demo.Accounts.User,
      hidden_fields: [:private_data],
      immutable_fields: [:encrypted_password, :inserted_at],
      components: [new: DemoWeb.CreateUserForm],
      label_with: :name,
      actions: [:deactivate, :activate, set_password: {__MODULE__, :set_password, 3}],
      tasks: [:regenerate_passwords, {__MODULE__, :aggregate, 4}],
      render_with: :render_field

  use PhoenixHTMLHelpers

  @doc """
  Argument will be base16 encoded, so, super safe
  """
  def set_password(user, _, new_password) do
    user =
      user
      |> Ecto.Changeset.change(encrypted_password: Base.encode16(new_password))
      |> Demo.Repo.update!()

    {:ok, user}
  end

  @doc """
  Deactivated users cannot login
  """
  def deactivate(user = %{active: true}, _) do
    user =
    user
    |> Ecto.Changeset.change(active: false)
    |> Demo.Repo.update!()

    {:ok, user}
  end

  def deactivate(_, _), do: {:error, "user not active"}

  def activate(user = %{active: false}, _) do
    user =
      user
      |> Ecto.Changeset.change(active: true)
      |> Demo.Repo.update!()

    {:ok, user}
  end

  def activate(_, _), do: {:error, "user already active"}

  def render_field(user, :email, _) do
    link(user.email, to: "mailto:\"#{user.name}\"<#{user.email}>")
  end

  def render_field(record, field, session) do
    DemoWeb.Renderer.render_field(record, field, session)
  end

  @doc """
  Regenerate all the passwords!

  Each user will get 16 random bytes of their very own.
  """
  def regenerate_passwords(query, session) do
    count = Demo.Repo.aggregate(Demo.Accounts.User, :count, prefix: session.prefix)

    query
    |> Demo.Repo.all(prefix: session.prefix)
    |> Enum.with_index()
    |> Enum.each(fn {user, i} ->
      user
      |> Ecto.Changeset.change(encrypted_password: :crypto.strong_rand_bytes(16) |> Base.encode16())
      |> Demo.Repo.update()

      LiveAdmin.PubSub.update_job(session.id, self(), progress: i/count, label: "Regenerating passwords")
    end)

    {:ok, "updated"}
  end

  @doc """
  Run a given aggregation on a given field.

  - Function should be one of the aggregates supported by Ecto: https://hexdocs.pm/ecto/Ecto.Repo.html#c:aggregate/4
  - Field should be a numeric field on the User schema
  """
  def aggregate(query, session, function, field) do
    result = Demo.Repo.aggregate(query, String.to_existing_atom(function), String.to_existing_atom(field), prefix: session.prefix)

    {:ok, result}
  end
end
