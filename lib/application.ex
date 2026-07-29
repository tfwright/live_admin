defmodule LiveAdmin.Application do
  use Application

  @compile_time_app_keys [
    :components,
    :query_with,
    :render_with,
    :delete_with,
    :create_with,
    :update_with,
    :validate_with,
    :label_with,
    :title_with,
    :hidden_fields,
    :immutable_fields,
    :actions,
    :tasks
  ]

  @compile_time_app_config %{
    components: Application.compile_env(:live_admin, :components),
    query_with: Application.compile_env(:live_admin, :query_with),
    render_with: Application.compile_env(:live_admin, :render_with),
    delete_with: Application.compile_env(:live_admin, :delete_with),
    create_with: Application.compile_env(:live_admin, :create_with),
    update_with: Application.compile_env(:live_admin, :update_with),
    validate_with: Application.compile_env(:live_admin, :validate_with),
    label_with: Application.compile_env(:live_admin, :label_with),
    title_with: Application.compile_env(:live_admin, :title_with),
    hidden_fields: Application.compile_env(:live_admin, :hidden_fields),
    immutable_fields: Application.compile_env(:live_admin, :immutable_fields),
    actions: Application.compile_env(:live_admin, :actions),
    tasks: Application.compile_env(:live_admin, :tasks)
  }

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: LiveAdmin.Supervisor]

    global_options_schema =
      LiveAdmin.base_configs_schema() ++
        [
          css_overrides: [type: {:or, [:string, {:tuple, [:atom, :atom, {:list, :any}]}]}],
          gettext_backend: [type: :atom],
          session_store: [type: :atom]
        ]

    NimbleOptions.validate!(Application.get_all_env(:live_admin), global_options_schema)

    validate_compile_time_config!()

    Supervisor.start_link(children(), opts)
  end

  @doc false
  def validate_compile_time_config! do
    @compile_time_app_keys
    |> Enum.filter(fn key ->
      Map.fetch!(@compile_time_app_config, key) != Application.get_env(:live_admin, key)
    end)
    |> case do
      [] ->
        :ok

      mismatches ->
        raise """
        The following :live_admin config keys have been set at runtime, but they must be set at compile time:

        #{Enum.map_join(mismatches, "\n", &"  * #{inspect(&1)}")}

        Move these into config/config.exs (or another compile-time config file).
        """
    end
  end

  defp children do
    [
      {LiveAdmin.Session.Agent, %{}},
      {Phoenix.PubSub, name: LiveAdmin.PubSub},
      {Task.Supervisor, name: LiveAdmin.Task.Supervisor}
    ]
  end
end
