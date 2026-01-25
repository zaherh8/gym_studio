defmodule GymStudio.Mailer do
  @moduledoc """
  Email delivery module using Swoosh.

  In development, emails are captured and viewable at `/dev/mailbox`.
  In production, configure with your preferred adapter.
  """
  use Swoosh.Mailer, otp_app: :gym_studio
end
