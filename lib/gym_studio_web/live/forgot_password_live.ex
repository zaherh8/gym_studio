defmodule GymStudioWeb.ForgotPasswordLive do
  @moduledoc """
  Forgot password flow with phone verification.

  Steps:
  1. Enter phone number
  2. OTP verification
  3. Set new password
  """
  use GymStudioWeb, :live_view

  alias GymStudio.Accounts
  alias GymStudio.Accounts.User
  alias GymStudio.PhoneUtils

  @resend_cooldown_seconds 60

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Forgot Password")
     |> assign(:step, :phone)
     |> assign(:local_number, "")
     |> assign(:phone_number, nil)
     |> assign(:otp_code, "")
     |> assign(:resend_countdown, 0)
     |> assign(:otp_error, nil)
     |> assign(:phone_error, nil)
     |> assign(
       :form,
       to_form(%{"password" => "", "password_confirmation" => ""}, as: "user")
     )
     |> assign(:check_errors, false)}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md py-8 px-4">
      <%!-- Brand Header --%>
      <div class="text-center mb-8">
        <h1 class="text-4xl font-black tracking-tight mb-2">
          <span class="text-primary">REACT</span> GYM
        </h1>
        <p class="text-base-content/60 text-sm">Private Studio in Lebanon</p>
      </div>

      <div class="card bg-base-200 shadow-xl">
        <div class="card-body">
          <h2 class="card-title justify-center text-2xl mb-1">Reset Password</h2>
          <p class="text-center text-base-content/60 text-sm mb-4">
            <%= case @step do %>
              <% :phone -> %>
                Enter your phone number to reset your password
              <% :verify -> %>
                Enter the verification code sent to your phone
              <% :password -> %>
                Choose a new password
            <% end %>
          </p>

          <%!-- Progress Steps --%>
          <ul class="steps steps-horizontal w-full mb-6">
            <li class={["step", @step in [:phone, :verify, :password] && "step-primary"]}>
              Phone
            </li>
            <li class={["step", @step in [:verify, :password] && "step-primary"]}>Verify</li>
            <li class={["step", @step == :password && "step-primary"]}>New Password</li>
          </ul>

          <%= case @step do %>
            <% :phone -> %>
              <.phone_step local_number={@local_number} phone_error={@phone_error} />
            <% :verify -> %>
              <.verify_step
                phone_number={@phone_number}
                otp_code={@otp_code}
                otp_error={@otp_error}
                resend_countdown={@resend_countdown}
              />
            <% :password -> %>
              <.password_step form={@form} check_errors={@check_errors} />
          <% end %>
        </div>
      </div>

      <p class="text-center text-sm mt-6 text-base-content/60">
        <.link navigate={~p"/users/log-in"} class="hover:underline">← Back to login</.link>
      </p>
    </div>
    """
  end

  # Phone Step Component
  attr :local_number, :string, required: true
  attr :phone_error, :string, default: nil

  defp phone_step(assigns) do
    ~H"""
    <form phx-submit="send_code" class="space-y-4">
      <div class="fieldset">
        <label class="label mb-1">Phone Number</label>
        <div class="join w-full">
          <span class="join-item flex items-center px-3 bg-base-300 border border-base-content/20 rounded-l-lg font-mono text-sm">
            🇱🇧 +961
          </span>
          <input
            type="tel"
            name="local_number"
            value={@local_number}
            placeholder="Enter phone number"
            class={["input join-item flex-1", @phone_error && "input-error"]}
            inputmode="tel"
            autocomplete="tel"
            required
            autofocus
          />
        </div>
        <p :if={@phone_error} class="mt-1.5 flex gap-2 items-center text-sm text-error">
          <.icon name="hero-exclamation-circle" class="size-5" />
          {@phone_error}
        </p>
      </div>

      <.button type="submit" class="btn btn-primary w-full">
        Send Verification Code
      </.button>
    </form>
    """
  end

  # Verify Step Component
  attr :phone_number, :string, required: true
  attr :otp_code, :string, required: true
  attr :otp_error, :string, default: nil
  attr :resend_countdown, :integer, required: true

  defp verify_step(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="text-center text-sm text-base-content/70 mb-4">
        We sent a code to
        <span class="font-semibold">{PhoneUtils.format_for_display(@phone_number)}</span>
      </div>

      <form phx-submit="verify_code" class="space-y-4">
        <div class="fieldset">
          <label class="label mb-1">Verification Code</label>
          <input
            type="text"
            name="otp_code"
            value={@otp_code}
            placeholder="Enter 6-digit code"
            class={[
              "input w-full text-center text-2xl tracking-[0.5em] font-mono",
              @otp_error && "input-error"
            ]}
            maxlength="6"
            inputmode="numeric"
            pattern="[0-9]*"
            autocomplete="one-time-code"
            phx-change="update_otp"
            required
          />
          <p :if={@otp_error} class="mt-1.5 flex gap-2 items-center text-sm text-error">
            <.icon name="hero-exclamation-circle" class="size-5" />
            {@otp_error}
          </p>
        </div>

        <.button type="submit" class="btn btn-primary w-full">
          Verify Code
        </.button>
      </form>

      <div class="flex justify-between items-center text-sm">
        <button type="button" phx-click="change_phone" class="text-primary hover:underline">
          Change phone number
        </button>

        <%= if @resend_countdown > 0 do %>
          <span class="text-base-content/50">
            Resend in {@resend_countdown}s
          </span>
        <% else %>
          <button type="button" phx-click="resend_code" class="text-primary hover:underline">
            Resend code
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  # Password Step Component
  attr :form, :any, required: true
  attr :check_errors, :boolean, required: true

  defp password_step(assigns) do
    ~H"""
    <.form for={@form} phx-submit="reset_password" phx-change="validate_password" class="space-y-4">
      <.input
        field={@form[:password]}
        type="password"
        label="New Password"
        placeholder="At least 12 characters"
        required
      />

      <.input
        field={@form[:password_confirmation]}
        type="password"
        label="Confirm New Password"
        placeholder="Re-enter your password"
        required
      />

      <.button type="submit" class="btn btn-primary w-full">
        Reset Password
      </.button>
    </.form>
    """
  end

  # Event Handlers

  def handle_event("send_code", %{"local_number" => local_number}, socket) do
    phone_number = PhoneUtils.normalize("+961", local_number)

    cond do
      !PhoneUtils.valid?(phone_number) ->
        {:noreply, assign(socket, :phone_error, "Please enter a valid phone number")}

      true ->
        # Always attempt to send verification, even for non-existing phones.
        # This prevents timing side-channel attacks that could reveal
        # whether a phone number is registered.
        if Accounts.phone_number_exists?(phone_number) do
          GymStudio.SMS.Telnyx.send_verification(phone_number)
        end

        # Always proceed to verify step regardless of phone existence or send result.
        # Non-existing phones will simply fail at the verify_code step.
        {:noreply,
         socket
         |> assign(:phone_number, phone_number)
         |> assign(:local_number, local_number)
         |> assign(:step, :verify)
         |> assign(:phone_error, nil)
         |> start_resend_countdown()}
    end
  end

  def handle_event("update_otp", %{"otp_code" => otp_code}, socket) do
    cleaned_code = String.replace(otp_code, ~r/[^\d]/, "")
    {:noreply, assign(socket, :otp_code, cleaned_code)}
  end

  def handle_event("verify_code", %{"otp_code" => otp_code}, socket) do
    cleaned_code = String.replace(otp_code, ~r/[^\d]/, "")

    case GymStudio.SMS.Telnyx.verify_code(socket.assigns.phone_number, cleaned_code) do
      :ok ->
        {:noreply,
         socket
         |> assign(:step, :password)
         |> assign(:otp_error, nil)}

      {:error, :invalid_code} ->
        {:noreply, assign(socket, :otp_error, "Invalid code. Please try again.")}

      {:error, _} ->
        {:noreply, assign(socket, :otp_error, "Verification failed. Please try again.")}
    end
  end

  def handle_event("change_phone", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, :phone)
     |> assign(:otp_code, "")
     |> assign(:otp_error, nil)}
  end

  def handle_event("resend_code", _params, socket) do
    if socket.assigns.resend_countdown > 0 do
      {:noreply, socket}
    else
      case GymStudio.SMS.Telnyx.send_verification(socket.assigns.phone_number) do
        {:ok, _verification_id} ->
          {:noreply,
           socket
           |> assign(:otp_error, nil)
           |> start_resend_countdown()
           |> put_flash(:info, "A new code has been sent")}

        {:error, _} ->
          {:noreply, assign(socket, :otp_error, "Unable to send code. Please try again.")}
      end
    end
  end

  def handle_event("validate_password", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "user"))}
  end

  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password_by_phone(socket.assigns.phone_number, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully")
         |> redirect(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:check_errors, true)
         |> assign(:form, to_form(changeset, as: "user"))}

      {:error, :user_not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Something went wrong. Please try again.")
         |> assign(:step, :phone)}
    end
  end

  def handle_info(:tick_countdown, socket) do
    new_countdown = max(0, socket.assigns.resend_countdown - 1)

    if new_countdown > 0 do
      Process.send_after(self(), :tick_countdown, 1000)
    end

    {:noreply, assign(socket, :resend_countdown, new_countdown)}
  end

  defp start_resend_countdown(socket) do
    Process.send_after(self(), :tick_countdown, 1000)
    assign(socket, :resend_countdown, @resend_cooldown_seconds)
  end
end
