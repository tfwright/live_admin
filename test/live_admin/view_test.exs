defmodule LiveAdmin.ViewTest do
  use ExUnit.Case, async: true

  alias LiveAdmin.View

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(LiveAdminTest.Repo)
  end

  describe "parse_search/1 with a field token" do
    setup do
      %{result: View.parse_search("test:test")}
    end

    test "returns a list", %{result: result} do
      assert [{"test", "test"}] = result
    end
  end

  describe "parse_search/1 with a general token" do
    setup do
      %{result: View.parse_search("test")}
    end

    test "returns a singleton item", %{result: result} do
      assert [{"*", "test"}] = result
    end
  end

  describe "parse_search/1 with a general token with spaces" do
    setup do
      %{result: View.parse_search("test test")}
    end

    test "returns a singleton item", %{result: result} do
      assert [{"*", "test test"}] = result
    end
  end

  describe "parse_search/1 with two field tokens" do
    setup do
      %{result: View.parse_search("one:test two:test")}
    end

    test "returns two filters", %{result: result} do
      assert [{"one", "test"}, {"two", "test"}] = result
    end
  end

  describe "parse_search/1 with a space before a field token" do
    setup do
      %{result: View.parse_search("test two:test")}
    end

    test "returns a single filters", %{result: result} do
      assert [{"*", "test two:test"}] = result
    end
  end

  describe "parse_search/1 with a space after a field token" do
    setup do
      %{result: View.parse_search("two:test test")}
    end

    test "returns a single filters", %{result: result} do
      assert [{"two", "test test"}] = result
    end
  end

  describe "parse_search/1 with blank token" do
    setup do
      %{result: View.parse_search(":")}
    end

    test "returns a list", %{result: result} do
      assert [{"*", ":"}] = result
    end
  end
end
