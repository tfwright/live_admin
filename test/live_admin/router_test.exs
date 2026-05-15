defmodule LiveAdmin.RouterTest do
  use ExUnit.Case, async: true

  import Mox

  alias LiveAdmin.Router

  setup :verify_on_exit!

  describe "build_session/4 with a compile-time resource option in app_config" do
    setup do
      stub_with(LiveAdminTest.MockSession, LiveAdminTest.StubSession)

      session =
        Router.build_session(
          %Plug.Conn{},
          "/admin",
          [],
          create_with: {SomeMod, :some_fun}
        )

      %{session: session}
    end

    test "resolves the option from app_config", %{session: session} do
      assert session["opts"][:create_with] == {SomeMod, :some_fun}
    end
  end

  describe "build_session/4 when a compile-time resource option is set in runtime Application env" do
    setup do
      stub_with(LiveAdminTest.MockSession, LiveAdminTest.StubSession)

      Application.put_env(:live_admin, :create_with, {RuntimeMod, :runtime_fun})
      on_exit(fn -> Application.delete_env(:live_admin, :create_with) end)

      session = Router.build_session(%Plug.Conn{}, "/admin", [], [])

      %{session: session}
    end

    test "ignores the runtime value", %{session: session} do
      refute session["opts"][:create_with]
    end
  end

  describe "build_session/4 list-typed resource options not provided in app_config" do
    setup do
      stub_with(LiveAdminTest.MockSession, LiveAdminTest.StubSession)

      session = Router.build_session(%Plug.Conn{}, "/admin", [], [])
      %{session: session}
    end

    test "default to an empty list", %{session: session} do
      assert session["opts"][:hidden_fields] == []
    end
  end

  describe "create_with: false and custom :create component at the resource level" do
    test "raises ArgumentError" do
      assert_raise ArgumentError, ~r/create_with: false.*:create component/, fn ->
        Router.__validate_config__!(LiveAdminTest.UserWithCustomCreate, [], [])
      end
    end
  end

  describe "create_with: false and custom :create component at the scope level" do
    test "raises ArgumentError" do
      assert_raise ArgumentError, ~r/create_with: false.*:create component/, fn ->
        Router.__validate_config__!(
          LiveAdminTest.User,
          [create_with: false, components: [create: LiveAdminTest.CustomFormComponent]],
          []
        )
      end
    end
  end

  describe "update_with: false and custom :edit component at the app level" do
    test "raises ArgumentError" do
      assert_raise ArgumentError, ~r/update_with: false.*:edit component/, fn ->
        Router.__validate_config__!(
          LiveAdminTest.User,
          [],
          update_with: false,
          components: [edit: LiveAdminTest.CustomFormComponent]
        )
      end
    end
  end

  describe "create_with: false at scope level with custom :create component at resource level" do
    test "returns :ok" do
      assert :ok ==
               Router.__validate_config__!(
                 LiveAdminTest.UserWithCustomCreateOnly,
                 [create_with: false],
                 []
               )
    end
  end

  describe "update_with: false at app level with custom :edit component at resource level" do
    test "returns :ok" do
      assert :ok ==
               Router.__validate_config__!(LiveAdminTest.UserWithCustomEditOnly, [],
                 update_with: false
               )
    end
  end

  describe "resource without conflicting config" do
    test "returns :ok" do
      assert :ok == Router.__validate_config__!(LiveAdminTest.User, [], [])
    end
  end
end
