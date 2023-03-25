defmodule LiveAdmin.Session.Store do
  @type session :: LiveAdmin.Session.t()
  @type conn :: Plug.Conn.t()

  @callback load!(conn) :: session
  @callback persist!(session) :: :ok
end
