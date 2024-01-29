defmodule Demo.Gettext do
  use Gettext, otp_app: :demo, priv: "dev/gettext"

  def locales, do: ["en", "tr"]
end
