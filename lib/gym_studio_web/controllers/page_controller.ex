defmodule GymStudioWeb.PageController do
  use GymStudioWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
