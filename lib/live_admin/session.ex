defmodule LiveAdmin.Session do
  use Ecto.Schema

  @type t() :: %__MODULE__{
          id: String.t(),
          __prefix__: String.t()
        }

  @primary_key {:id, :string, autogenerate: false}
  embedded_schema do
    field(:__prefix__, :string)
  end
end
