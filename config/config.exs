import Config

config :phoenix, :json_library, Jason
config :phoenix, :stacktrace_depth, 20

config :logger, level: :warning
config :logger, :console, format: "[$level] $message\n"

config :phoenix, LiveAdmin.Endpoint,
  watchers: [
    node: ["esbuild.js", "--watch", cd: Path.expand("../assets", __DIR__)]
  ]

config :docout,
  app_name: :live_admin,
  formatters: [LiveAdmin.READMECompiler]
