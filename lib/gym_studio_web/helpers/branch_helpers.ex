defmodule GymStudioWeb.Helpers.BranchHelpers do
  @moduledoc """
  Shared helpers for branch-related display logic.

  Used across multiple admin LiveViews to avoid duplication.
  """

  @day_labels %{
    "mon" => "Monday",
    "tue" => "Tuesday",
    "wed" => "Wednesday",
    "thu" => "Thursday",
    "fri" => "Friday",
    "sat" => "Saturday",
    "sun" => "Sunday"
  }

  @doc """
  Returns the full day name for a short day key.

  ## Examples

      iex> day_label("mon")
      "Monday"

      iex> day_label("unknown")
      "unknown"
  """
  def day_label(day) when is_binary(day) do
    Map.get(@day_labels, day, day)
  end

  @doc """
  Parses a role string safely using a whitelist approach.

  Returns the atom if it's a valid role, or `:client` as default.

  ## Examples

      iex> parse_role("trainer")
      :trainer

      iex> parse_role("hacker")
      :client

      iex> parse_role(nil)
      :client
  """
  def parse_role(nil), do: :client

  def parse_role(role) when is_binary(role) do
    if role in ~w(client trainer admin) do
      String.to_existing_atom(role)
    else
      :client
    end
  end

  @doc """
  Safely parses a string to integer, returning nil for invalid input.

  ## Examples

      iex> safe_string_to_integer("42")
      42

      iex> safe_string_to_integer("")
      nil

      iex> safe_string_to_integer("abc")
      nil
  """
  def safe_string_to_integer(""), do: nil

  def safe_string_to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  def safe_string_to_integer(value) when is_integer(value), do: value

  def safe_string_to_integer(_), do: nil
end
