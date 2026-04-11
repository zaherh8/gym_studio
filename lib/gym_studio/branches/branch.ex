defmodule GymStudio.Branches.Branch do
  @moduledoc """
  Schema for gym branch locations.

  Each branch represents a physical gym location with its own capacity,
  contact details, and operating hours.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
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
  Changeset for creating and updating branches.
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
    |> unique_constraint(:slug)
  end
end
