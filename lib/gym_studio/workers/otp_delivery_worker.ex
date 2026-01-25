defmodule GymStudio.Workers.OtpDeliveryWorker do
  @moduledoc """
  Oban worker for delivering OTP codes via SMS.

  Currently logs to console for development. In production,
  this should be integrated with an SMS provider (e.g., Twilio, Nexmo).
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"phone_number" => phone_number, "code" => code, "purpose" => purpose}}) do
    # In development, log the code to console
    # In production, replace this with actual SMS delivery
    Logger.info("""
    ==========================================
    OTP Code Delivery
    ==========================================
    Phone: #{phone_number}
    Code: #{code}
    Purpose: #{purpose}
    ==========================================
    """)

    # TODO: Integrate with SMS provider
    # Example with Twilio:
    # ExTwilio.Message.create(%{
    #   to: phone_number,
    #   from: System.get_env("TWILIO_PHONE_NUMBER"),
    #   body: "Your GymStudio verification code is: #{code}"
    # })

    :ok
  end
end
