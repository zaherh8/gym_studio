defmodule GymStudioWeb.RegistrationLive do
  @moduledoc """
  Multi-step registration flow with phone verification.

  Steps:
  1. Phone entry with country code selector
  2. OTP verification
  3. Password setup (with optional email)
  """
  use GymStudioWeb, :live_view

  alias GymStudio.Accounts
  alias GymStudio.Accounts.User
  alias GymStudio.PhoneUtils
  alias GymStudio.RateLimiter

  @resend_cooldown_seconds 60

  def mount(_params, _session, socket) do
    client_ip = get_client_ip(socket)

    {:ok,
     socket
     |> assign(:page_title, "Register")
     |> assign(:step, :phone)
     |> assign(:country_code, PhoneUtils.default_dial_code())
     |> assign(:local_number, "")
     |> assign(:phone_number, nil)
     |> assign(:otp_code, "")
     |> assign(:resend_countdown, 0)
     |> assign(:otp_error, nil)
     |> assign(:phone_error, nil)
     |> assign(:client_ip, client_ip)
     |> assign(
       :form,
       to_form(%{"name" => "", "password" => "", "password_confirmation" => "", "email" => ""},
         as: "user"
       )
     )
     |> assign(:check_errors, false)}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md py-8 px-4">
      <.header class="text-center mb-8">
        Create your account
        <:subtitle>
          <%= case @step do %>
            <% :phone -> %>
              Enter your phone number to get started
            <% :verify -> %>
              Enter the verification code
            <% :password -> %>
              Set up your password
          <% end %>
        </:subtitle>
      </.header>
      
    <!-- Progress Steps -->
      <ul class="steps steps-horizontal w-full mb-8">
        <li class={["step", @step in [:phone, :verify, :password] && "step-primary"]}>Phone</li>
        <li class={["step", @step in [:verify, :password] && "step-primary"]}>Verify</li>
        <li class={["step", @step == :password && "step-primary"]}>Complete</li>
      </ul>

      <%= case @step do %>
        <% :phone -> %>
          <.phone_step
            country_code={@country_code}
            local_number={@local_number}
            phone_error={@phone_error}
          />
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

      <p class="text-center text-sm mt-8">
        Already have an account?
        <.link navigate={~p"/users/log-in"} class="font-semibold text-primary hover:underline">
          Sign in
        </.link>
      </p>
    </div>
    """
  end

  # Phone Step Component
  attr :country_code, :string, required: true
  attr :local_number, :string, required: true
  attr :phone_error, :string, default: nil

  defp phone_step(assigns) do
    ~H"""
    <form phx-submit="send_code" phx-change="validate_phone" class="space-y-4">
      <div class="fieldset">
        <label class="label mb-1">Phone Number</label>
        <div class="join w-full">
          <select
            name="country_code"
            class="select join-item w-32"
            phx-change="change_country"
          >
            <%= for {label, value} <- PhoneUtils.country_options() do %>
              <option value={value} selected={value == @country_code}>{label}</option>
            <% end %>
          </select>
          <input
            type="tel"
            name="local_number"
            value={@local_number}
            placeholder="Enter phone number"
            class={["input join-item flex-1", @phone_error && "input-error"]}
            inputmode="tel"
            autocomplete="tel"
            required
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
    <.form
      for={@form}
      phx-submit="complete_registration"
      phx-change="validate_password"
      class="space-y-4"
    >
      <.input
        field={@form[:name]}
        type="text"
        label="Full Name"
        placeholder="Enter your full name"
        required
      />

      <.input
        field={@form[:password]}
        type="password"
        label="Password"
        placeholder="At least 12 characters"
        required
      />

      <.input
        field={@form[:password_confirmation]}
        type="password"
        label="Confirm Password"
        placeholder="Re-enter your password"
        required
      />

      <.input
        field={@form[:email]}
        type="email"
        label="Email (optional)"
        placeholder="For account recovery"
      />

      <.button type="submit" class="btn btn-primary w-full">
        Create Account
      </.button>
    </.form>
    """
  end

  # Event Handlers

  def handle_event("change_country", %{"country_code" => country_code}, socket) do
    {:noreply, assign(socket, :country_code, country_code)}
  end

  def handle_event("validate_phone", %{"local_number" => local_number} = params, socket) do
    country_code = params["country_code"] || socket.assigns.country_code

    {:noreply,
     socket
     |> assign(:local_number, local_number)
     |> assign(:country_code, country_code)
     |> assign(:phone_error, nil)}
  end

  def handle_event("send_code", %{"local_number" => local_number} = params, socket) do
    country_code = params["country_code"] || socket.assigns.country_code
    phone_number = PhoneUtils.normalize(country_code, local_number)

    cond do
      !PhoneUtils.valid?(phone_number) ->
        {:noreply, assign(socket, :phone_error, "Please enter a valid phone number")}

      Accounts.phone_number_exists?(phone_number) ->
        # Generic error to prevent user enumeration
        {:noreply,
         assign(socket, :phone_error, "Unable to send verification code. Please try again.")}

      RateLimiter.check_ip_rate(socket.assigns.client_ip) == {:error, :rate_limited} ->
        {:noreply, assign(socket, :phone_error, "Too many requests. Please try again later.")}

      RateLimiter.check_phone_daily_rate(phone_number) == {:error, :rate_limited} ->
        {:noreply,
         assign(
           socket,
           :phone_error,
           "Too many verification attempts today. Please try again tomorrow."
         )}

      true ->
        case GymStudio.SMS.Telnyx.send_verification(phone_number) do
          {:ok, _verification_id} ->
            {:noreply,
             socket
             |> assign(:phone_number, phone_number)
             |> assign(:local_number, local_number)
             |> assign(:country_code, country_code)
             |> assign(:step, :verify)
             |> assign(:phone_error, nil)
             |> start_resend_countdown()}

          {:error, _reason} ->
            {:noreply,
             assign(socket, :phone_error, "Unable to send verification code. Please try again.")}
        end
    end
  end

  def handle_event("update_otp", %{"otp_code" => otp_code}, socket) do
    # Only allow digits
    cleaned_code = String.replace(otp_code, ~r/[^\d]/, "")
    {:noreply, assign(socket, :otp_code, cleaned_code)}
  end

  def handle_event("verify_code", %{"otp_code" => otp_code}, socket) do
    cleaned_code = String.replace(otp_code, ~r/[^\d]/, "")

    # Use Telnyx Verify API for code verification
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
    cond do
      socket.assigns.resend_countdown > 0 ->
        {:noreply, socket}

      RateLimiter.check_ip_rate(socket.assigns.client_ip) == {:error, :rate_limited} ->
        {:noreply, assign(socket, :otp_error, "Too many requests. Please try again later.")}

      RateLimiter.check_phone_daily_rate(socket.assigns.phone_number) == {:error, :rate_limited} ->
        {:noreply,
         assign(
           socket,
           :otp_error,
           "Too many verification attempts today. Please try again tomorrow."
         )}

      true ->
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
      |> Accounts.change_user_registration(user_params,
        validate_unique: false,
        hash_password: false
      )
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: "user"))}
  end

  def handle_event("complete_registration", %{"user" => user_params}, socket) do
    # Add the verified phone number to the params
    user_params =
      user_params
      |> Map.put("phone_number", socket.assigns.phone_number)

    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Mark the user as confirmed since phone was verified
        {:ok, _confirmed_user} = Accounts.confirm_user(user)

        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully!")
         |> redirect(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:check_errors, true)
         |> assign(:form, to_form(changeset, as: "user"))}
    end
  end

  def handle_info(:tick_countdown, socket) do
    new_countdown = max(0, socket.assigns.resend_countdown - 1)

    if new_countdown > 0 do
      Process.send_after(self(), :tick_countdown, 1000)
    end

    {:noreply, assign(socket, :resend_countdown, new_countdown)}
  end

  # Private helpers

  defp start_resend_countdown(socket) do
    Process.send_after(self(), :tick_countdown, 1000)
    assign(socket, :resend_countdown, @resend_cooldown_seconds)
  end

  defp get_client_ip(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} -> :inet.ntoa(address) |> to_string()
      _ -> "unknown"
    end
  end
end
