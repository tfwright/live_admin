import Config

config :phoenix, :json_library, Jason
config :phoenix, :stacktrace_depth, 20

config :logger, level: :warning
config :logger, :console, format: "[$level] $message\n"

config :docout,
  app_name: :live_admin,
  formatters: [LiveAdmin.READMECompiler]

config :phoenix_live_view, :colocated_js,
  target_directory: Path.expand("../assets/node_modules/phoenix-colocated", __DIR__)
