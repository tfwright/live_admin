defmodule LiveAdmin.ApplicationTest do
  use ExUnit.Case, async: false

  describe "validate_compile_time_config! when a resource option is set at runtime" do
    setup do
      Application.put_env(:live_admin, :create_with, {RuntimeMod, :runtime_fun})
      on_exit(fn -> Application.delete_env(:live_admin, :create_with) end)

      :ok
    end

    test "raises pointing the user to compile-time config" do
      assert_raise RuntimeError, ~r/create_with/, fn ->
        LiveAdmin.Application.validate_compile_time_config!()
      end
    end
  end

  describe "validate_compile_time_config! when no resource options diverge between compile and runtime env" do
    test "returns :ok" do
      assert :ok == LiveAdmin.Application.validate_compile_time_config!()
    end
  end
end
