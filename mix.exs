defmodule PhoenixLiveAdmin.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_live_admin,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix_live_view, "~> 0.16"},
      {:ecto, "~> 3.6.2 or ~> 3.7", only: [:dev, :test]},
      {:ecto_psql_extras, "~> 0.7", only: [:dev, :test]},
    ]
  end
end
