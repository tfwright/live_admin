defmodule LiveAdmin.PubSub do
  @moduledoc """
    PubSub system for exchanging messages with LiveAdmin.

    Includes the following events:
      * :job - Shows progress bar indicating status of any ongoing process. LiveAdmin uses this internally to indicate progress of actions on multiple records and tasks. Metadata consists of `pid`, `progress` float/int, and `label` string.
      * :announce - Show temporary message with severity level. Meta consists of `message` string, and `type` (`:error`, `:success`, or `:info`)

    Currently just a thin wrapper around Phoenix.PubSub, so its possible to use that directly, but discouraged since that may change.
  """

  @type session_id :: String.t()

  @spec broadcast(session_id, {atom(), map()}) :: :ok
  @spec broadcast({atom(), map()}) :: :ok
  @doc """
    Notify LiveAdmin of event, consisting of a unique name (either global or scoped to the session, if that is passed) and metadata.
  """
  def broadcast(session_id \\ nil, event) do
    Phoenix.PubSub.broadcast(
      __MODULE__,
      if(session_id, do: "session:#{session_id}", else: "all"),
      event
    )

    :ok
  end

  @spec subscribe(session_id) :: :ok
  @spec subscribe() :: :ok
  @doc """
    Subscribe to LiveAdmin events for a specific session.
  """
  def subscribe(session_id), do: Phoenix.PubSub.subscribe(__MODULE__, "session:#{session_id}")

  @doc """
    Subscribe to *all* LiveAdmin events.
  """
  def subscribe(), do: Phoenix.PubSub.subscribe(__MODULE__, "all")
end
