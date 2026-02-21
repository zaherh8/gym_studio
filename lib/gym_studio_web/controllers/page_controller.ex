defmodule GymStudioWeb.PageController do
  use GymStudioWeb, :controller

  alias GymStudio.Accounts

  def home(conn, _params) do
    trainers = Accounts.list_approved_trainers()
    render(conn, :home, trainers: trainers)
  end
end
