defmodule LiveAdminTest do
  use ExUnit.Case, async: true

  alias LiveAdmin.Resource

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(LiveAdminTest.Repo)
  end

  describe "associated_resource/3 when association schema is not a configured resource" do
    test "returns nil" do
      assert is_nil(LiveAdmin.associated_resource(LiveAdminTest.User, :some_id, []))
    end
  end

  describe "associated_resource/3 when association schema is a configured resource" do
    test "returns the association schema" do
      assert %Resource{schema: LiveAdminTest.User} =
               LiveAdmin.associated_resource(LiveAdminTest.Post, :user_id, [
                 {nil, %Resource{schema: LiveAdminTest.User}}
               ])
    end
  end

  describe "record_label/2 when config uses mfa" do
    assert 1 =
             LiveAdmin.record_label(%{id: 1}, %Resource{config: %{label_with: {Map, :get, [:id]}}})
  end
end
