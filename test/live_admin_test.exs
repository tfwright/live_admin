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
      assert {nil, LiveAdminTest.User} =
               LiveAdmin.associated_resource(LiveAdminTest.Post, :user_id, [
                 {nil, LiveAdminTest.User}
               ])
    end
  end

  describe "fetch_config/3 for :immutable_fields when resource does not set it" do
    setup do
      %{
        result:
          LiveAdmin.fetch_config(LiveAdminTest.PostResource, :immutable_fields,
            immutable_fields: [:inserted_at]
          )
      }
    end

    test "returns value from config", %{result: result} do
      assert result == [:inserted_at]
    end
  end

  describe "fetch_config/3 for :immutable_fields when resource sets it explicitly" do
    setup do
      %{
        result:
          LiveAdmin.fetch_config(LiveAdminTest.User, :immutable_fields,
            immutable_fields: [:inserted_at]
          )
      }
    end

    test "returns resource-level value", %{result: result} do
      assert result == [:encrypted_password]
    end
  end

  describe "record_label/2 when config uses mfa" do
    assert 1 =
             LiveAdmin.record_label(%LiveAdminTest.Post{post_id: 1}, LiveAdminTest.PostResource,
               label_with: {LiveAdminTest.PostResource, :label}
             )
  end
end
