defmodule LiveAdmin.Notifier do
  @spec job(LiveAdmin.Session.t(), pid(), float() | integer(), [label: String.t()]) :: :ok
  @spec job(LiveAdmin.Session.t(), pid(), float() | integer()) :: :ok
  def job(session, pid, progress, opts \\ [])

  def job(session, pid, 0, opts),
    do: broadcast(session, {:job, pid, :start, Keyword.get(opts, :label, "")})

  def job(session, pid, progress, _) when progress >= 1,
    do: broadcast(session, {:job, pid, :complete})

  def job(session, pid, progress, _), do: broadcast(session, {:job, pid, :progress, progress})

  def broadcast(session, info) do
    Phoenix.PubSub.broadcast(
      LiveAdmin.PubSub,
      "session:#{session.id}",
      info
    )

    :ok
  end
end
