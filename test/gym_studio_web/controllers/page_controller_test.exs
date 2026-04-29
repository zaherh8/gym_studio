defmodule GymStudioWeb.PageControllerTest do
  use GymStudioWeb.ConnCase

  import GymStudio.AccountsFixtures
  import GymStudio.BranchesFixtures

  alias GymStudio.Branches

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "react-wordmark"
    assert response =~ "Where Fitness Meets"
  end

  # [LANDING-PAGE] Trainers section hidden for landing page release - see #92
  test "GET / does not show trainers section", %{conn: conn} do
    admin = user_fixture(%{role: :admin})

    trainer =
      trainer_fixture(%{
        bio: "Expert in strength training",
        specializations: ["Strength", "HIIT"]
      })

    GymStudio.Accounts.approve_trainer(trainer, admin)

    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    refute response =~ "Meet Your"
    refute response =~ "Expert in strength training"
  end

  describe "branches assign" do
    test "GET / assigns active branches only", %{conn: conn} do
      _active = branch_fixture(%{name: "Active Branch", slug: "active-branch"})

      _inactive =
        branch_fixture(%{name: "Inactive Branch", slug: "inactive-branch", active: false})

      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ "Active Branch"
      refute response =~ "Inactive Branch"
    end

    test "GET / displays branch details in Our Locations section", %{conn: conn} do
      _branch =
        branch_fixture(%{
          name: "React — Sin El Fil",
          address: "Horsh Tabet, Clover Park Bldg., 4th Floor",
          phone: "+961 71 104 483",
          latitude: 33.8723,
          longitude: 35.5316,
          operating_hours: %{
            "mon" => "06:00-22:00",
            "tue" => "06:00-22:00",
            "wed" => "06:00-22:00",
            "thu" => "06:00-22:00",
            "fri" => "06:00-22:00",
            "sat" => "08:00-18:00",
            "sun" => "08:00-18:00"
          }
        })

      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ "React — Sin El Fil"
      assert response =~ "Horsh Tabet, Clover Park Bldg., 4th Floor"
      assert response =~ "+961 71 104 483"
      assert response =~ "Get Directions"
      assert response =~ "google.com/maps"
    end

    test "GET / handles zero branches gracefully", %{conn: conn} do
      # Deactivate all branches
      for branch <- Branches.list_branches() do
        Branches.update_branch(branch, %{active: false})
      end

      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      assert response =~ "Location details coming soon"
    end

    test "GET / handles branch with nil operating_hours", %{conn: conn} do
      _branch =
        branch_fixture(%{
          name: "No Hours Branch",
          slug: "no-hours-branch",
          operating_hours: nil
        })

      conn = get(conn, ~p"/")
      response = html_response(conn, 200)

      # Branch should still render without error
      assert response =~ "No Hours Branch"
      # Operating hours section should be omitted entirely
      refute response =~ "Mon:"
    end

    # [LANDING-PAGE] Trainer cards hidden for landing page release - see #92
    # test "GET / shows branch badge on trainer cards" - skipped
  end
end
