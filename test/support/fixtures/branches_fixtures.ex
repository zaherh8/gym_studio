defmodule GymStudio.BranchesFixtures do
  @moduledoc """
  Test fixtures for the Branches context.
  """

  alias GymStudio.Branches

  @doc """
  Generate a branch.

  ## Options

    - `:name` - Branch name (default: "Test Branch")
    - `:slug` - Branch slug (default: "test-branch-{unique}")
    - `:capacity` - Branch capacity (default: 4)

  ## Examples

      iex> branch_fixture()
      %Branch{}

      iex> branch_fixture(%{name: "Sin El Fil"})
      %Branch{}
  """
  def branch_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    attrs =
      Enum.into(attrs, %{
        name: "Test Branch #{unique}",
        slug: "test-branch-#{unique}",
        capacity: 4,
        active: true
      })

    {:ok, branch} = Branches.create_branch(attrs)
    branch
  end
end
