defmodule LiveAdmin.ResourceTest do
  use ExUnit.Case, async: true

  alias LiveAdmin.Resource

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(LiveAdminTest.Repo)
  end

  describe "render/6 with a list of maps field handled by default implementation" do
    test "returns a list with safe pre" do
      assert Resource.render(
               %{previous_versions: [%{}]},
               :previous_versions,
               LiveAdminTest.PostResource,
               nil,
               %{},
               render_with: nil
             )
             |> List.first()
             |> Phoenix.HTML.safe_to_string() =~ ~r/pre/
    end
  end
end
