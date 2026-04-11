defmodule GymStudio.Branches.Branch do
  @moduledoc """
  Schema for gym branch locations.

  Each branch represents a physical gym location with its own capacity,
  contact details, and operating hours.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "branches" do
    field :name, :string
    field :slug, :string
    field :address, :string
    field :capacity, :integer
    field :phone, :string
    field :latitude, :float
    field :longitude, :float
    field :operating_hours, :map
    field :active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating branches.

  Slug is immutable once set — use `update_changeset/2` for updates.
  """
  def changeset(branch, attrs) do
    branch
    |> cast(attrs, [
      :name,
      :slug,
      :address,
      :capacity,
      :phone,
      :latitude,
      :longitude,
      :operating_hours,
      :active
    ])
    |> validate_required([:name, :slug, :capacity])
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/,
      message: "must be a valid slug (lowercase letters, numbers, and hyphens)"
    )
    |> validate_number(:capacity, greater_than: 0)
    |> validate_operating_hours()
    |> unique_constraint(:slug)
  end

  @doc """
  Changeset for updating branches.

  Slug is excluded — it cannot be changed after creation.
  """
  def update_changeset(branch, attrs) do
    branch
    |> cast(attrs, [
      :name,
      :address,
      :capacity,
      :phone,
      :latitude,
      :longitude,
      :operating_hours,
      :active
    ])
    |> validate_required([:name, :capacity])
    |> validate_number(:capacity, greater_than: 0)
    |> validate_operating_hours()
  end

  @hours_regex ~r/^\d{2}:\d{2}-\d{2}:\d{2}$/

  defp validate_operating_hours(changeset) do
    case get_change(changeset, :operating_hours) do
      nil ->
        changeset

      hours when is_map(hours) ->
        invalid =
          hours
          |> Enum.filter(fn {_day, val} -> is_binary(val) and val != "" end)
          |> Enum.any?(fn {_day, val} -> val =~ @hours_regex == false end)

        if invalid do
          add_error(
            changeset,
            :operating_hours,
            "must be in HH:MM-HH:MM format (e.g. 06:00-22:00)"
          )
        else
          changeset
        end

      _ ->
        changeset
    end
  end
end
