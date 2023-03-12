defmodule LiveAdmin.Session do
  use Ecto.Schema

  alias __MODULE__.Store

  @primary_key {:id, :string, autogenerate: false}
  embedded_schema do
    field(:__prefix__, :string)
  end
end
