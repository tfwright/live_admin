defmodule LiveAdmin.MixProject do
  use Mix.Project

  def project do
    [
      app: :live_admin,
      name: "LiveAdmin",
      description: "A admin UI for Phoenix applications built with LiveView",
      version: "0.6.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),
      package: [
        maintainers: ["Thomas Floyd Wright"],
        licenses: ["Apache-2.0"],
        links: %{"GitHub" => "https://github.com/tfwright/live_admin"},
        files: ~w(lib .formatter.exs mix.exs README* dist)
      ],
      source_url: "https://github.com/tfwright/live_admin",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      compilers: Mix.compilers() ++ compilers(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {LiveAdmin.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix_live_view, "~> 0.18"},
      {:ecto, "~> 3.8"},
      {:ecto_sql, "~> 3.8"},
      {:phoenix_ecto, "~> 4.4"},
      {:plug_cowboy, "~> 2.0", only: :dev},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:jason, "~> 1.3", only: [:dev, :test]},
      {:ecto_psql_extras, "~> 0.7", only: [:dev, :test]},
      {:faker, "~> 0.17", only: :dev},
      {:floki, ">= 0.30.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:docout, github: "tfwright/docout", branch: "main", runtime: false, only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      dev: ["run --no-halt dev.exs"]
    ]
  end

  defp compilers(env) do
    if env == :dev && System.get_env("LIVE_ADMIN_DEV") do
      [:docout]
    else
      []
    end
  end

  defp elixirc_paths(env) do
    if env == :dev && System.get_env("LIVE_ADMIN_DEV") do
      ["lib", "dev"]
    else
      ["lib"]
    end
  end
end
