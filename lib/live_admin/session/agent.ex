defmodule LiveAdmin.Session.Agent do
  defmodule InvalidSessionId do
    defexception [:message]

    def exception(id) do
      message = """
      Could not load session with id `#{id}`

      This can occur if the server was restarted (clearing the store) while sockets were still connected.
      As the session will be automatically regenerated on reload, you can ignore this error.
      """

      %__MODULE__{message: message}
    end
  end

  use Agent

  @behaviour LiveAdmin.Session.Store

  def start_link(%{} = initial_state) do
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
  end

  @impl LiveAdmin.Session.Store
  def init!(conn) do
    id = Map.get(conn.assigns, :user_id, Ecto.UUID.generate())

    Agent.update(__MODULE__, fn state ->
      Map.put_new(state, id, %LiveAdmin.Session{id: id})
    end)

    id
  end

  @impl LiveAdmin.Session.Store
  def load!(id) do
    Agent.get(__MODULE__, &Map.get(&1, id)) || raise InvalidSessionId, id
  end

  @impl LiveAdmin.Session.Store
  def persist!(session) do
    Agent.update(__MODULE__, fn sessions ->
      Map.put(sessions, session.id, session)
    end)

    :ok
  end
end
