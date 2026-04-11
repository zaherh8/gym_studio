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
  Gets the default branch (first active branch).

  Returns `nil` if no active branches exist.

  ## Examples

      iex> get_default_branch()
      %Branch{}

      iex> get_default_branch()
      nil
  """
  def get_default_branch do
    Branch
    |> where([b], b.active == true)
    |> order_by([b], asc: b.id)
    |> limit(1)
    |> Repo.one()
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

  @doc """
  Returns branch stats: client count, trainer count, sessions this week.

  ## Examples

      iex> get_branch_stats(1)
      %{client_count: 10, trainer_count: 3, sessions_this_week: 25}
  """
  def get_branch_stats(branch_id) do
    alias GymStudio.Accounts.User
    alias GymStudio.Scheduling.TrainingSession

    client_count =
      from(u in User,
        where: u.branch_id == ^branch_id and u.role == :client,
        select: count(u.id)
      )
      |> Repo.one()

    trainer_count =
      from(u in User,
        where: u.branch_id == ^branch_id and u.role == :trainer,
        select: count(u.id)
      )
      |> Repo.one()

    now = DateTime.utc_now()
    start_of_week = Date.beginning_of_week(now, :monday)
    start_of_week_dt = DateTime.new!(start_of_week, ~T[00:00:00], "Etc/UTC")

    sessions_this_week =
      from(s in TrainingSession,
        where: s.branch_id == ^branch_id and s.scheduled_at >= ^start_of_week_dt,
        select: count(s.id)
      )
      |> Repo.one()

    %{
      client_count: client_count,
      trainer_count: trainer_count,
      sessions_this_week: sessions_this_week
    }
  end

  @doc """
  Toggles a branch's active status.

  ## Examples

      iex> toggle_branch_active(branch)
      {:ok, %Branch{}}
  """
  def toggle_branch_active(%Branch{} = branch) do
    branch
    |> Branch.update_changeset(%{active: !branch.active})
    |> Repo.update()
  end

  @doc """
  Returns a changeset for tracking branch form changes.
  """
  def change_branch(%Branch{} = branch, attrs \\ %{}) do
    Branch.changeset(branch, attrs)
  end
end
