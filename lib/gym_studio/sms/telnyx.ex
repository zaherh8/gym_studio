defmodule GymStudio.SMS.Telnyx do
  @moduledoc """
  Telnyx Verify API integration for OTP delivery.

  Uses Telnyx Verify to send and verify OTP codes via SMS.
  Telnyx handles code generation, SMS delivery, and verification.
  Falls back to mock mode in dev/test when no API key is configured.
  """

  require Logger

  @base_url "https://api.telnyx.com/v2"

  @doc """
  Sends an OTP verification code via Telnyx Verify API.

  Telnyx generates the code and sends it via SMS.
  Returns {:ok, verification_id} on success.
  """
  def send_verification(phone_number) do
    case api_key() do
      nil ->
        Logger.warning("[Telnyx] API key not configured — mock mode")
        Logger.info("[Telnyx Mock] OTP would be sent to #{phone_number}")
        {:ok, "mock-verification-id"}

      key ->
        do_send_verification(phone_number, key)
    end
  end

  defp do_send_verification(phone_number, api_key) do
    body = %{
      phone_number: phone_number,
      verify_profile_id: verify_profile_id(),
      type: "sms"
    }

    case Req.post("#{@base_url}/verifications/sms",
           json: body,
           headers: [{"authorization", "Bearer #{api_key}"}]
         ) do
      {:ok, %Req.Response{status: status, body: %{"data" => data}}} when status in 200..299 ->
        Logger.info("[Telnyx] Verification sent to #{phone_number}, id=#{data["id"]}")
        {:ok, data["id"]}

      {:ok, %Req.Response{status: _status, body: %{"errors" => [error | _]}}} ->
        detail = error["detail"] || error["title"] || "Unknown error"
        Logger.error("[Telnyx] Send verification failed: #{detail}")
        {:error, detail}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("[Telnyx] Send verification failed: status=#{status} body=#{inspect(body)}")
        {:error, :delivery_failed}

      {:error, reason} ->
        Logger.error("[Telnyx] Request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  @doc """
  Verifies an OTP code via Telnyx Verify API.

  Returns :ok on valid code, {:error, reason} on invalid/expired.
  """
  def verify_code(phone_number, code) do
    case api_key() do
      nil ->
        # In mock mode, accept code "000000" for testing
        if code == "000000" do
          Logger.info("[Telnyx Mock] Code accepted for #{phone_number}")
          :ok
        else
          Logger.warning("[Telnyx Mock] Invalid mock code for #{phone_number}")
          {:error, :invalid_code}
        end

      key ->
        do_verify_code(phone_number, code, key)
    end
  end

  defp do_verify_code(phone_number, code, api_key) do
    encoded_phone = URI.encode(phone_number)

    body = %{
      code: code,
      verify_profile_id: verify_profile_id()
    }

    case Req.post(
           "#{@base_url}/verifications/by_phone_number/#{encoded_phone}/actions/verify",
           json: body,
           headers: [{"authorization", "Bearer #{api_key}"}]
         ) do
      {:ok, %Req.Response{status: status, body: %{"data" => data}}} when status in 200..299 ->
        if data["response_code"] == "accepted" do
          Logger.info("[Telnyx] Code verified for #{phone_number}")
          :ok
        else
          Logger.warning("[Telnyx] Code rejected for #{phone_number}: #{data["response_code"]}")
          {:error, :invalid_code}
        end

      {:ok, %Req.Response{status: status}} when status in 400..499 ->
        {:error, :invalid_code}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("[Telnyx] Verify error: status=#{status} body=#{inspect(body)}")
        {:error, :verification_failed}

      {:error, reason} ->
        Logger.error("[Telnyx] Verify request failed: #{inspect(reason)}")
        {:error, :request_failed}
    end
  end

  defp api_key do
    System.get_env("TELNYX_API_KEY")
  end

  defp verify_profile_id do
    System.get_env("TELNYX_VERIFY_PROFILE_ID") || "4900017e-24a6-c82b-0b96-69fc7c905b53"
  end
end
