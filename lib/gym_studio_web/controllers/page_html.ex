defmodule GymStudioWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use GymStudioWeb, :html

  embed_templates "page_html/*"

  @day_labels %{
    "mon" => "Mon",
    "tue" => "Tue",
    "wed" => "Wed",
    "thu" => "Thu",
    "fri" => "Fri",
    "sat" => "Sat",
    "sun" => "Sun"
  }

  @weekday_order ~w(mon tue wed thu fri sat sun)

  @doc """
  Formats operating hours map into human-readable grouped ranges.

  Consecutive days with identical hours are grouped (e.g. "Mon - Fri: 6:00 AM - 10:00 PM").
  """
  @spec format_operating_hours(map() | nil) :: [String.t()]
  def format_operating_hours(nil), do: []

  def format_operating_hours(hours) when is_map(hours) do
    @weekday_order
    |> Enum.map(fn day ->
      {day, Map.get(hours, day, "")}
    end)
    |> group_consecutive_days()
    |> Enum.map(&format_group/1)
  end

  defp group_consecutive_days(days_with_hours) do
    days_with_hours
    |> Enum.filter(fn {_day, hours} -> hours != "" end)
    |> Enum.chunk_while(
      [],
      fn
        {day, hours}, [] ->
          {:cont, [{day, hours}]}

        {day, hours}, [{_, prev_hours} | _] = acc when hours == prev_hours ->
          {:cont, acc ++ [{day, hours}]}

        {day, hours}, acc ->
          {:cont, acc, [{day, hours}]}
      end,
      fn
        [] -> {:cont, []}
        acc -> {:cont, acc, []}
      end
    )
  end

  defp format_group([{day, hours}]) do
    "#{@day_labels[day]}: #{format_time_range(hours)}"
  end

  defp format_group(days) do
    first = @day_labels[elem(hd(days), 0)]
    last = @day_labels[elem(List.last(days), 0)]
    {_, hours} = hd(days)
    "#{first} - #{last}: #{format_time_range(hours)}"
  end

  defp format_time_range(range) when is_binary(range) do
    case String.split(range, "-") do
      [start_time, end_time] ->
        "#{format_time(start_time)} - #{format_time(end_time)}"

      _ ->
        range
    end
  end

  defp format_time(time_str) when is_binary(time_str) do
    case String.split(time_str, ":") do
      [h, m] ->
        case Integer.parse(h) do
          {hour, ""} when hour >= 0 and hour <= 23 ->
            cond do
              hour == 0 -> "12:#{m} AM"
              hour < 12 -> "#{hour}:#{m} AM"
              hour == 12 -> "12:#{m} PM"
              true -> "#{hour - 12}:#{m} PM"
            end

          _ ->
            time_str
        end

      _ ->
        time_str
    end
  end
end
