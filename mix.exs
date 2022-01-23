defmodule PhoenixLiveAdmin.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_live_admin,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {PhoenixLiveAdmin.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix_live_view, "~> 0.17"},
      {:ecto, "~> 3.6.2 or ~> 3.7"},
      {:phoenix_ecto, "~> 4.4"},
      {:plug_cowboy, "~> 2.0", only: :dev},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:jason, "~> 1.3", only: [:dev, :test]},
      {:ecto_psql_extras, "~> 0.7", only: [:dev, :test]},
      {:faker, "~> 0.17", only: :dev},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp aliases do
    [
      dev: ["run --no-halt dev.exs"]
    ]
  end
end
