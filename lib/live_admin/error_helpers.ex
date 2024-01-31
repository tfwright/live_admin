defmodule LiveAdmin.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  import Phoenix.HTML.Form
  use PhoenixHTMLHelpers

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn {desc, _details} ->
      content_tag(:span, desc,
        class: "resource__error",
        phx_feedback_for: input_id(form, field)
      )
    end)
  end
end
