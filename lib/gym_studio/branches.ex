defmodule GymStudio.Branches do
  @moduledoc """
  The Branches context handles gym branch locations.

  Provides CRUD operations for managing physical gym locations,
  including listing, creating, updating, and deleting branches.
  """

  import Ecto.Query, warn: false
  alias GymStudio.Repo
  alias GymStudio.Branches.Branch

  @doc """
  Returns the list of branches.

  ## Options

    - `:active` - Filter by active status (true/false)

  ## Examples

      iex> list_branches()
      [%Branch{}, ...]

      iex> list_branches(active: true)
      [%Branch{}, ...]
  """
  @spec list_branches(keyword()) :: [Branch.t()]
  def list_branches(opts \\ []) do
    query =
      if Keyword.has_key?(opts, :active) do
        where(Branch, [b], b.active == ^opts[:active])
      else
        Branch
      end

    query
    |> order_by([b], asc: b.name)
    |> Repo.all()
  end

  @doc """
  Gets a single branch.

  Raises `Ecto.NoResultsError` if the branch does not exist.

  ## Examples

      iex> get_branch!(1)
      %Branch{}

      iex> get_branch!(999)
      ** (Ecto.NoResultsError)
  """
  def get_branch!(id) do
    Repo.get!(Branch, id)
  end

  @doc """
  Gets a branch by slug.

  Returns `nil` if no branch is found.

  ## Examples

      iex> get_branch_by_slug("sin-el-fil")
      %Branch{}

      iex> get_branch_by_slug("nonexistent")
      nil
  """
  def get_branch_by_slug(slug) do
    Repo.get_by(Branch, slug: slug)
  end

  @doc """
  Creates a branch.

  ## Examples

      iex> create_branch(%{name: "React — Sin El Fil", slug: "sin-el-fil", capacity: 4})
      {:ok, %Branch{}}

      iex> create_branch(%{name: nil})
      {:error, %Ecto.Changeset{}}
  """
  def create_branch(attrs) do
    %Branch{}
    |> Branch.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a branch.

  ## Examples

      iex> update_branch(branch, %{capacity: 6})
      {:ok, %Branch{}}

      iex> update_branch(branch, %{capacity: -1})
      {:error, %Ecto.Changeset{}}
  """
  def update_branch(%Branch{} = branch, attrs) do
    branch
    |> Branch.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a branch.

  > #### Warning {: .warning}
  > Deleting a branch will fail with a foreign key constraint error once
  > associations (e.g. sessions, trainers) are added in future issues.

  ## Examples

      iex> delete_branch(branch)
      {:ok, %Branch{}}

      iex> delete_branch(branch)
      {:error, %Ecto.Changeset{}}
  """
  def delete_branch(%Branch{} = branch) do
    Repo.delete(branch)
  end
end
