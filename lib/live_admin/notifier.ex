defmodule LiveAdmin.Notifier do
  @type announce_opts :: [type: :error | :success | :info]

  @spec broadcast(LiveAdmin.Session.t(), any()) :: :ok
  @spec broadcast(any()) :: :ok
  def broadcast(session \\ nil, info) do
    Phoenix.PubSub.broadcast(
      LiveAdmin.PubSub,
      if(session, do: "session:#{session.id}", else: "all"),
      info
    )

    :ok
  end

  @spec announce(String.t()) :: :ok
  @spec announce(String.t(), announce_opts) :: :ok
  @spec announce(LiveAdmin.Session.t(), String.t(), announce_opts) :: :ok
  @spec announce(LiveAdmin.Session.t(), String.t()) :: :ok
  def announce(session \\ nil, message, opts \\ []),
    do: broadcast(session, {:announce, message, Keyword.get(opts, :type, :info)})

  @spec job(LiveAdmin.Session.t(), pid(), float() | integer(), label: String.t()) :: :ok
  @spec job(LiveAdmin.Session.t(), pid(), float() | integer()) :: :ok
  def job(session, pid, progress, opts \\ [])

  def job(session, pid, 0, opts),
    do: broadcast(session, {:job, pid, :start, Keyword.get(opts, :label, "")})

  def job(session, pid, progress, _) when progress >= 1,
    do: broadcast(session, {:job, pid, :complete})

  def job(session, pid, progress, _), do: broadcast(session, {:job, pid, :progress, progress})
end
