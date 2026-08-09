defmodule LiveAdmin.Session.Store do
  @moduledoc """
  Behaviour for persisting LiveAdmin sessions.

  A session holds per-user UI state (page size, sorting, prefix, etc.) that must
  outlive individual LiveView mounts. LiveAdmin looks the store up from the
  `:session_store` application config and defaults to `LiveAdmin.Session.Agent`,
  an in-memory implementation.

  Provide your own module to persist sessions elsewhere (for example a database
  or cache so state survives server restarts) by implementing these callbacks
  and setting:

      config :live_admin, session_store: MyApp.LiveAdmin.SessionStore
  """

  @type session :: LiveAdmin.Session.t()
  @type conn :: Plug.Conn.t()
  @type id :: String.t()
  @type live_session :: map()

  @doc """
  Establishes the session for `conn` and returns its id.

  Called during the plug pipeline. Implementations should derive a stable id
  (for example from the authenticated user) and ensure a session exists for it,
  creating one if necessary.
  """
  @callback init!(conn) :: id

  @doc """
  Loads and returns the session identified by `id`.

  Called on LiveView mount. Implementations should raise if no session exists
  for `id` (it will be regenerated on the next request).
  """
  @callback load!(id) :: session

  @doc """
  Persists `session`, keyed by its id, and returns `:ok`.

  Called whenever session state changes so subsequent `load!/1` calls observe
  the update.
  """
  @callback persist!(session) :: :ok
end
