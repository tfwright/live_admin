defmodule LiveAdmin.Application do
  use Application

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: LiveAdmin.Supervisor]

    global_options_schema =
      LiveAdmin.base_configs_schema() ++
        [
          css_overrides: [type: :string],
          gettext_backend: [type: :atom],
          session_store: [type: :atom]
        ]

    NimbleOptions.validate!(Application.get_all_env(:live_admin), global_options_schema)

    Supervisor.start_link(children(), opts)
  end

  defp children do
    [
      {LiveAdmin.Session.Agent, %{}},
      {Phoenix.PubSub, name: LiveAdmin.PubSub},
      {Task.Supervisor, name: LiveAdmin.Task.Supervisor}
    ]
  end
end
