defmodule GymStudioWeb.PageControllerTest do
  use GymStudioWeb.ConnCase

  import GymStudio.AccountsFixtures

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "REACT"
    assert response =~ "GYM"
    assert response =~ "Where Fitness Meets"
  end

  test "GET / shows dynamic trainers from DB", %{conn: conn} do
    admin = user_fixture(%{role: :admin})

    trainer =
      trainer_fixture(%{
        bio: "Expert in strength training",
        specializations: ["Strength", "HIIT"]
      })

    # Approve the trainer so it shows on homepage
    GymStudio.Accounts.approve_trainer(trainer, admin)

    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "Expert in strength training"
    assert response =~ "Strength &amp; HIIT"
  end

  test "GET / handles zero trainers gracefully", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "Our trainer profiles are being updated"
  end

  test "GET / does not show unapproved trainers", %{conn: conn} do
    _trainer =
      trainer_fixture(%{
        bio: "Should not appear on homepage"
      })

    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    refute response =~ "Should not appear on homepage"
  end

  test "GET / shows updated contact info", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "Horsh Tabet, Clover Park Bldg."
    assert response =~ "Sin El Fil, Lebanon"
    assert response =~ "+961 71 104 483"
    refute response =~ "123 Fitness Street"
    refute response =~ "+961 1 234 567"
    refute response =~ "hello@reactgym.com"
  end
end
