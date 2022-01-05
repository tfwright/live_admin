defmodule Phoenix.LiveAdmin.Router do
  defmacro live_admin(path) do
    quote do
      scope unquote(path), alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        live_session :live_admin, root_layout: {Phoenix.LiveAdmin.LayoutView, "live.html"} do
          live "/", Phoenix.LiveAdmin.Components.Home, :home, as: :home
        end
      end
    end
  end
end
