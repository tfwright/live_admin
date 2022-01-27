defmodule Phoenix.LiveAdmin.SessionStore do
  use Agent

  def start_link(%{} = initial_state) do
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
  end

  def lookup(id) do
    Agent.get(__MODULE__, &Map.get(&1, id))
  end

  def lookup(id, key) do
    Agent.get(__MODULE__, &get_in(&1, [id, key]))
  end

  def set(id, key, val) do
    Agent.update(__MODULE__, &put_in(&1, [id, key], val))
  end

  def get_or_init(id) do
    Agent.get_and_update(__MODULE__, fn state ->
      new_state = Map.put_new(state, id, %{})

      {state, new_state}
    end)
  end
end
