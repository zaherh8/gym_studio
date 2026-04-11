defmodule GymStudioWeb.Helpers.BranchHelpersTest do
  use ExUnit.Case, async: true

  alias GymStudioWeb.Helpers.BranchHelpers

  describe "day_label/1" do
    test "returns full day names for valid keys" do
      assert BranchHelpers.day_label("mon") == "Monday"
      assert BranchHelpers.day_label("tue") == "Tuesday"
      assert BranchHelpers.day_label("wed") == "Wednesday"
      assert BranchHelpers.day_label("thu") == "Thursday"
      assert BranchHelpers.day_label("fri") == "Friday"
      assert BranchHelpers.day_label("sat") == "Saturday"
      assert BranchHelpers.day_label("sun") == "Sunday"
    end

    test "returns the key for unknown days" do
      assert BranchHelpers.day_label("unknown") == "unknown"
    end
  end

  describe "parse_role/1" do
    test "returns atom for valid roles" do
      assert BranchHelpers.parse_role("client") == :client
      assert BranchHelpers.parse_role("trainer") == :trainer
      assert BranchHelpers.parse_role("admin") == :admin
    end

    test "returns :client for invalid roles" do
      assert BranchHelpers.parse_role("hacker") == :client
      assert BranchHelpers.parse_role("") == :client
      assert BranchHelpers.parse_role(nil) == :client
    end
  end

  describe "safe_string_to_integer/1" do
    test "parses valid integer strings" do
      assert BranchHelpers.safe_string_to_integer("42") == 42
      assert BranchHelpers.safe_string_to_integer("1") == 1
    end

    test "returns nil for empty strings" do
      assert BranchHelpers.safe_string_to_integer("") == nil
    end

    test "returns nil for invalid strings" do
      assert BranchHelpers.safe_string_to_integer("abc") == nil
      assert BranchHelpers.safe_string_to_integer("12abc") == nil
    end

    test "returns integer for integer input" do
      assert BranchHelpers.safe_string_to_integer(42) == 42
    end

    test "returns nil for nil input" do
      assert BranchHelpers.safe_string_to_integer(nil) == nil
    end
  end
end
