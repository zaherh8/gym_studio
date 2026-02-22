defmodule GymStudio.Workers.OtpDeliveryWorker do
  @moduledoc """
  Oban worker for delivering OTP codes via Telnyx SMS.
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"phone_number" => phone_number, "code" => _code, "purpose" => purpose}
      }) do
    Logger.info("[OTP] Sending verification to #{phone_number} for #{purpose}")

    case GymStudio.SMS.Telnyx.send_verification(phone_number) do
      {:ok, _verification_id} ->
        :ok

      {:error, reason} ->
        Logger.error("[OTP] Failed to send to #{phone_number}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
