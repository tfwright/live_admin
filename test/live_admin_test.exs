defmodule LiveAdminTest do
  use ExUnit.Case, async: true

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
      assert {_, {LiveAdminTest.User, _}} =
               LiveAdmin.associated_resource(LiveAdminTest.Post, :user_id, [
                 {nil, {LiveAdminTest.User, nil}}
               ])
    end
  end

  describe "record_label/2 when config uses mfa" do
    assert 1 = LiveAdmin.record_label(%{id: 1}, %{label_with: {Map, :get, [:id]}})
  end
end
