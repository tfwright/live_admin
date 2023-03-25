defmodule LiveAdmin.Session.Agent do
  use Agent

  @behaviour LiveAdmin.Session.Store

  def start_link(%{} = initial_state) do
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
  end

  @impl LiveAdmin.Session.Store
  def init!(_) do
    id = Ecto.UUID.generate()

    Agent.get_and_update(__MODULE__, fn state ->
      new_state = Map.put(state, id, %LiveAdmin.Session{id: id})

      {state, new_state}
    end)

    id
  end

  @impl LiveAdmin.Session.Store
  def load!(id) do
    Agent.get(__MODULE__, &Map.get(&1, id))
  end

  @impl LiveAdmin.Session.Store
  def persist!(session) do
    Agent.update(__MODULE__, fn sessions ->
      Map.put(sessions, session.id, session)
    end)

    :ok
  end
end
