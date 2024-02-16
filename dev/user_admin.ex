defmodule DemoWeb.UserAdmin do
  use LiveAdmin.Resource,
      schema: Demo.Accounts.User,
      hidden_fields: [:private_data],
      immutable_fields: [:encrypted_password, :inserted_at],
      components: [new: DemoWeb.CreateUserForm],
      label_with: :name,
      actions: [:deactivate, :set_password],
      tasks: [:regenerate_passwords, :aggregate],
      render_with: :render_field

  use PhoenixHTMLHelpers

  def set_password(user, _, new_password) do
    user =
      user
      |> Ecto.Changeset.change(encrypted_password: Base.encode16(new_password))
      |> Demo.Repo.update!()

    {:ok, user}
  end

  def deactivate(user, _) do
    user
    |> Ecto.Changeset.change(active: false)
    |> Demo.Repo.update()
    |> case do
      {:ok, user} -> {:ok, user}
      error -> error
    end
  end

  def render_field(user, :email, _) do
    link(user.email, to: "mailto:\"#{user.name}\"<#{user.email}>")
  end

  def render_field(record, field, session) do
    DemoWeb.Renderer.render_field(record, field, session)
  end

  def regenerate_passwords(session) do
    Demo.Accounts.User
    |> Demo.Repo.all(prefix: session.prefix)
    |> Enum.each(fn user ->
      user
      |> Ecto.Changeset.change(encrypted_password: :crypto.strong_rand_bytes(16) |> Base.encode16())
      |> Demo.Repo.update()
    end)

    {:ok, "updated"}
  end

  def aggregate(session, function, field) do
    result = Demo.Repo.aggregate(Demo.Accounts.User, String.to_existing_atom(function), String.to_existing_atom(field), prefix: session.prefix)

    {:ok, result}
  end
end
