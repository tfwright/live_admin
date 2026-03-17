defmodule Demo.Populator do
  import Ecto.Query

  alias Demo.Repo

  def reset do
    teardown()
    run()
  end

  def run do
    Enum.each(1..Enum.random(1..10001), fn _ ->
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
            categories:
              Ecto.Enum.values(Demo.Posts.Post, :categories) |> Enum.take(Enum.random(0..2)),
            tags: Faker.Lorem.words(Enum.random(0..5)),
            body: Faker.Lorem.paragraphs() |> Enum.join("\n\n"),
            disabled_user: get_user_if(:rand.uniform(2) == 1),
            previous_versions: [
              %Demo.Posts.Post.Version{body: Faker.Lorem.paragraphs() |> Enum.join("\n\n")}
            ]
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

  defp get_user_if(true),
    do: from(Demo.Accounts.User, order_by: fragment("RANDOM()"), limit: 1) |> Demo.Repo.one()

  defp get_user_if(false), do: nil
end
