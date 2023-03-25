defmodule LiveAdmin.Session.Store do
  @type session :: LiveAdmin.Session.t()
  @type conn :: Plug.Conn.t()
  @type id :: String.t()

  @callback init!(conn) :: id
  @callback load!(id) :: session
  @callback persist!(session) :: :ok
end
