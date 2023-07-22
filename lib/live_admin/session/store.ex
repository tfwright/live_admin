defmodule LiveAdmin.Session.Store do
  @type session :: LiveAdmin.Session.t()
  @type conn :: Plug.Conn.t()
  @type id :: String.t()
  @type live_session :: map()

  @callback init!(conn) :: id
  @callback load!(id) :: session
  @callback persist!(session) :: :ok
  @callback on_mount(session, live_session) :: session

  @optional_callbacks on_mount: 2
end
