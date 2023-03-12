defmodule LiveAdmin.Session.Store do
  @type id :: String.t()
  @type conn :: Plug.Conn.t()

  @callback load!(conn) :: LiveAdmin.Session.t()
  @callback persist!(id) :: :ok
end
