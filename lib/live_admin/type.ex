defmodule LiveAdmin.Type do
  @moduledoc """
  Defines the behavior for custom Ecto types that can be used within LiveAdmin.

  Modules implementing this behavior must specify:
  - A primitive type to be treated as
  """

  @callback render_as() :: atom()
end
