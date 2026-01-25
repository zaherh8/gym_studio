defmodule GymStudio.PhoneUtils do
  @moduledoc """
  Utilities for phone number handling including country codes and E.164 normalization.
  """

  @countries [
    %{code: "LB", dial_code: "+961", name: "Lebanon", flag: "\u{1F1F1}\u{1F1E7}"},
    %{code: "AE", dial_code: "+971", name: "UAE", flag: "\u{1F1E6}\u{1F1EA}"},
    %{code: "SA", dial_code: "+966", name: "Saudi Arabia", flag: "\u{1F1F8}\u{1F1E6}"},
    %{code: "JO", dial_code: "+962", name: "Jordan", flag: "\u{1F1EF}\u{1F1F4}"},
    %{code: "EG", dial_code: "+20", name: "Egypt", flag: "\u{1F1EA}\u{1F1EC}"},
    %{code: "US", dial_code: "+1", name: "United States", flag: "\u{1F1FA}\u{1F1F8}"},
    %{code: "GB", dial_code: "+44", name: "United Kingdom", flag: "\u{1F1EC}\u{1F1E7}"},
    %{code: "FR", dial_code: "+33", name: "France", flag: "\u{1F1EB}\u{1F1F7}"},
    %{code: "DE", dial_code: "+49", name: "Germany", flag: "\u{1F1E9}\u{1F1EA}"},
    %{code: "IT", dial_code: "+39", name: "Italy", flag: "\u{1F1EE}\u{1F1F9}"}
  ]

  @default_country_code "LB"

  @doc """
  Returns the list of supported countries with their dial codes and flags.
  Lebanon is first as the default.
  """
  def countries, do: @countries

  @doc """
  Returns the default country code.
  """
  def default_country_code, do: @default_country_code

  @doc """
  Returns country options formatted for select dropdowns.

  ## Examples

      iex> GymStudio.PhoneUtils.country_options()
      [{"🇱🇧 Lebanon (+961)", "+961"}, ...]
  """
  def country_options do
    Enum.map(@countries, fn country ->
      {"#{country.flag} #{country.name} (#{country.dial_code})", country.dial_code}
    end)
  end

  @doc """
  Gets country info by dial code.

  ## Examples

      iex> GymStudio.PhoneUtils.get_country_by_dial_code("+961")
      %{code: "LB", dial_code: "+961", name: "Lebanon", flag: "🇱🇧"}
  """
  def get_country_by_dial_code(dial_code) do
    Enum.find(@countries, fn country -> country.dial_code == dial_code end)
  end

  @doc """
  Gets the default dial code for Lebanon.
  """
  def default_dial_code do
    country = get_country_by_dial_code("+961")
    country.dial_code
  end

  @doc """
  Normalizes a phone number to E.164 format.

  ## Examples

      iex> GymStudio.PhoneUtils.normalize("+961", "1234567")
      "+9611234567"

      iex> GymStudio.PhoneUtils.normalize("+961", "  123 456 7  ")
      "+9611234567"
  """
  def normalize(dial_code, local_number) when is_binary(dial_code) and is_binary(local_number) do
    # Remove all non-digit characters from local number
    cleaned_local =
      local_number
      |> String.replace(~r/[^\d]/, "")
      |> String.trim_leading("0")

    dial_code <> cleaned_local
  end

  def normalize(_, _), do: nil

  @doc """
  Validates if a phone number is in E.164 format.

  E.164 format: + followed by country code and national number (8-15 digits total)

  ## Examples

      iex> GymStudio.PhoneUtils.valid?("+9611234567")
      true

      iex> GymStudio.PhoneUtils.valid?("1234567")
      false

      iex> GymStudio.PhoneUtils.valid?("+123")
      false
  """
  def valid?(phone_number) when is_binary(phone_number) do
    Regex.match?(~r/^\+[1-9]\d{7,14}$/, phone_number)
  end

  def valid?(_), do: false

  @doc """
  Formats a phone number for display.

  ## Examples

      iex> GymStudio.PhoneUtils.format_for_display("+9611234567")
      "+961 1234567"
  """
  def format_for_display(phone_number) when is_binary(phone_number) do
    # Find matching country code
    country =
      Enum.find(@countries, fn c ->
        String.starts_with?(phone_number, c.dial_code)
      end)

    case country do
      nil ->
        phone_number

      %{dial_code: dial_code} ->
        local = String.replace_prefix(phone_number, dial_code, "")
        "#{dial_code} #{local}"
    end
  end

  def format_for_display(_), do: ""
end
