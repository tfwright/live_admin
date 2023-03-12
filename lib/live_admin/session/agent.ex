defmodule LiveAdmin.Session.Agent do
  use Agent

  @behaviour LiveAdmin.Session.Store

  def start_link(%{} = initial_state) do
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
  end

  @impl LiveAdmin.Session.Store
  def load!(_) do
    id = Ecto.UUID.generate()

    Agent.get_and_update(__MODULE__, fn state ->
      new_state = Map.put_new(state, id, %LiveAdmin.Session{id: id})

      {state, new_state}
    end)

    Agent.get(__MODULE__, &Map.fetch!(&1, id))
  end

  @impl LiveAdmin.Session.Store
  def persist!(session) do
    Agent.update(__MODULE__, fn sessions ->
      Map.put(sessions, session.id, session)
    end)

    :ok
  end
end
