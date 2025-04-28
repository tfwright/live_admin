defmodule Demo.Gettext do
  use Gettext.Backend, otp_app: :demo, priv: "dev/gettext"

  def locales, do: ["en", "tr"]
end
