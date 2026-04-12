defmodule GymStudioWeb.PageHTMLTest do
  use ExUnit.Case, async: true

  alias GymStudioWeb.PageHTML

  describe "format_operating_hours/1" do
    test "returns empty list for nil" do
      assert PageHTML.format_operating_hours(nil) == []
    end

    test "returns empty list for empty map" do
      assert PageHTML.format_operating_hours(%{}) == []
    end

    test "formats single day" do
      hours = %{"mon" => "06:00-22:00"}
      assert PageHTML.format_operating_hours(hours) == ["Mon: 6:00 AM - 10:00 PM"]
    end

    test "groups consecutive days with same hours" do
      hours = %{
        "mon" => "06:00-22:00",
        "tue" => "06:00-22:00",
        "wed" => "06:00-22:00",
        "thu" => "06:00-22:00",
        "fri" => "06:00-22:00",
        "sat" => "08:00-18:00",
        "sun" => "08:00-18:00"
      }

      result = PageHTML.format_operating_hours(hours)

      assert result == [
               "Mon - Fri: 6:00 AM - 10:00 PM",
               "Sat - Sun: 8:00 AM - 6:00 PM"
             ]
    end

    test "handles midnight (00:00)" do
      hours = %{"mon" => "00:00-23:59"}
      assert PageHTML.format_operating_hours(hours) == ["Mon: 12:00 AM - 11:59 PM"]
    end

    test "handles noon (12:00)" do
      hours = %{"mon" => "12:00-13:00"}
      assert PageHTML.format_operating_hours(hours) == ["Mon: 12:00 PM - 1:00 PM"]
    end

    test "handles mixed hours across days" do
      hours = %{
        "mon" => "06:00-22:00",
        "tue" => "06:00-22:00",
        "wed" => "06:00-22:00",
        "thu" => "07:00-21:00",
        "fri" => "07:00-21:00",
        "sat" => "08:00-18:00",
        "sun" => "08:00-18:00"
      }

      result = PageHTML.format_operating_hours(hours)

      assert result == [
               "Mon - Wed: 6:00 AM - 10:00 PM",
               "Thu - Fri: 7:00 AM - 9:00 PM",
               "Sat - Sun: 8:00 AM - 6:00 PM"
             ]
    end

    test "skips days with empty hours" do
      hours = %{
        "mon" => "06:00-22:00",
        "tue" => "06:00-22:00",
        "wed" => "",
        "thu" => "",
        "fri" => "",
        "sat" => "08:00-18:00",
        "sun" => "08:00-18:00"
      }

      result = PageHTML.format_operating_hours(hours)

      assert result == [
               "Mon - Tue: 6:00 AM - 10:00 PM",
               "Sat - Sun: 8:00 AM - 6:00 PM"
             ]
    end

    test "skips days not present in the map" do
      hours = %{
        "mon" => "06:00-22:00",
        "sat" => "08:00-18:00"
      }

      result = PageHTML.format_operating_hours(hours)

      assert result == [
               "Mon: 6:00 AM - 10:00 PM",
               "Sat: 8:00 AM - 6:00 PM"
             ]
    end

    test "handles PM hours correctly" do
      hours = %{"mon" => "14:00-20:00"}
      assert PageHTML.format_operating_hours(hours) == ["Mon: 2:00 PM - 8:00 PM"]
    end

    test "handles malformed time input gracefully" do
      hours = %{"mon" => "abc:00-22:00"}
      assert PageHTML.format_operating_hours(hours) == ["Mon: abc:00 - 10:00 PM"]
    end

    test "handles out-of-range hour gracefully" do
      hours = %{"mon" => "25:00-22:00"}
      assert PageHTML.format_operating_hours(hours) == ["Mon: 25:00 - 10:00 PM"]
    end
  end
end
