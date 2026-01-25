defmodule GymStudioWeb.PageControllerTest do
  use GymStudioWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "REACT"
    assert response =~ "GYM"
    assert response =~ "Where Fitness Meets"
  end
end
