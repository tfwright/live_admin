defmodule Phoenix.LiveAdmin.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field, opts \\ []) do
    Enum.map(Keyword.get_values(form.errors, field), fn {desc, _details} ->
      content_tag(:span, desc,
        class: "text-red-500",
        phx_feedback_for: input_id(form, field)
      )
    end)
  end
end
