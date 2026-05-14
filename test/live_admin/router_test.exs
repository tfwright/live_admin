defmodule LiveAdmin.RouterTest do
  use ExUnit.Case, async: true

  alias LiveAdmin.Router

  describe "create_with: false at resource level with custom :create component at resource level" do
    test "raises ArgumentError" do
      assert_raise ArgumentError, ~r/create_with: false.*:create component/, fn ->
        Router.__validate_config__!(LiveAdminTest.UserWithCustomCreate, [], [])
      end
    end
  end

  describe "create_with: false at scope level with custom :create component at resource level" do
    test "raises ArgumentError" do
      assert_raise ArgumentError, ~r/create_with: false.*:create component/, fn ->
        Router.__validate_config__!(
          LiveAdminTest.UserWithCustomCreateOnly,
          [create_with: false],
          []
        )
      end
    end
  end

  describe "update_with: false at app level with custom :edit component at resource level" do
    test "raises ArgumentError" do
      assert_raise ArgumentError, ~r/update_with: false.*:edit component/, fn ->
        Router.__validate_config__!(LiveAdminTest.UserWithCustomEditOnly, [], update_with: false)
      end
    end
  end

  describe "resource without conflicting config" do
    test "returns :ok" do
      assert :ok == Router.__validate_config__!(LiveAdminTest.User, [], [])
    end
  end
end
