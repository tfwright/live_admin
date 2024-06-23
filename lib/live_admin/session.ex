defmodule LiveAdmin.Session do
  use Ecto.Schema

  @type t() :: %__MODULE__{
          id: String.t(),
          prefix: String.t(),
          locale: String.t(),
          metadata: map(),
          index_page_size: :integer
        }

  @primary_key {:id, :string, autogenerate: false}
  embedded_schema do
    field(:prefix, :string)
    field(:locale, :string, default: "en")
    field(:metadata, :map, default: %{})
    field(:index_page_size, :integer, default: 10)
  end
end
