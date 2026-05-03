defmodule GymStudioWeb.OfferLive do
  @moduledoc """
  Campaign landing page at /offer for the "Lift Off" marketing campaign.
  Standalone conversion page — one job: get visitors to WhatsApp in under 10 seconds.
  No auth, no DB reads, no nav, no footer.
  """
  use GymStudioWeb, :live_view

  @whatsapp_base_url "https://wa.me/96170379764"
  @whatsapp_message "Hi! I found the flyer and want to claim my free session at React 🏋️"

  @impl true
  def mount(params, _session, socket) do
    utm_source = Map.get(params, "utm_source")
    utm_campaign = Map.get(params, "utm_campaign")
    utm_content = Map.get(params, "utm_content")

    whatsapp_url = build_whatsapp_url(utm_source, utm_campaign, utm_content)
    message = build_whatsapp_message(utm_source, utm_campaign, utm_content)

    socket =
      socket
      |> assign(:page_title, "React — Claim Your Free Session")
      |> assign(:whatsapp_url, whatsapp_url)
      |> assign(:whatsapp_message, message)
      |> assign(:utm_source, utm_source)
      |> assign(:utm_campaign, utm_campaign)
      |> assign(:utm_content, utm_content)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen w-full relative flex flex-col items-center justify-center px-6 py-5 overflow-hidden">
      <%!-- Background image with dark overlay --%>
      <div class="absolute inset-0 z-0">
        <img
          src={~p"/images/offer-hero.jpg"}
          alt=""
          class="w-full h-full object-cover object-center"
          loading="eager"
        />
        <div class="absolute inset-0 bg-gradient-to-b from-black/60 via-black/70 to-black/85"></div>
      </div>

      <%!-- Content --%>
      <div class="relative z-10 flex flex-col items-center justify-center">
        <%!-- Logo --%>
        <div class="mb-3">
          <img
            src={~p"/images/logo/react-wordmark-white.svg"}
            alt="React"
            class="h-9 w-auto"
          />
        </div>

        <%!-- Headline --%>
        <h1 class="text-3xl sm:text-4xl font-black text-center tracking-tight leading-tight mb-4">
          <span class="text-primary">YOUR FIRST SESSION</span> <br />
          <span class="text-primary">IS ON US</span>
        </h1>

        <%!-- Benefits --%>
        <ul class="w-full max-w-sm space-y-2.5 mb-6">
          <li class="flex items-start gap-3">
            <svg
              class="w-6 h-6 text-primary flex-shrink-0 mt-0.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2.5"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
            </svg>
            <span class="text-white/90 text-base">1 free private training session</span>
          </li>
          <li class="flex items-start gap-3">
            <svg
              class="w-6 h-6 text-primary flex-shrink-0 mt-0.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2.5"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
            </svg>
            <span class="text-white/90 text-base">No commitment, no card</span>
          </li>
          <li class="flex items-start gap-3">
            <svg
              class="w-6 h-6 text-primary flex-shrink-0 mt-0.5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2.5"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
            </svg>
            <span class="text-white/90 text-base">In the heart of Horsh Tabet</span>
          </li>
        </ul>

        <%!-- CTA Button --%>
        <a
          href={@whatsapp_url}
          target="_blank"
          rel="noopener noreferrer"
          class="flex items-center justify-center gap-2 w-full max-w-sm py-4 px-6 rounded-full bg-primary text-white font-bold text-lg border border-primary hover:bg-primary-focus hover:shadow-lg hover:shadow-primary/30 hover:scale-[1.02] active:scale-[0.98] transition-all duration-200"
        >
          <Layouts.whatsapp_icon class="w-6 h-6" />
          <span>CLAIM YOUR FREE SESSION</span>
        </a>

        <%!-- Location --%>
        <div class="mt-6 flex items-center gap-2 text-white/50 text-sm">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
            />
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
          <span>Clover Park, 4th floor — Sin El Fil</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Builds the WhatsApp URL with the pre-filled message.
  UTM params are embedded in the message text so gym staff can see the source.
  """
  def build_whatsapp_url(utm_source, utm_campaign, utm_content) do
    message = build_whatsapp_message(utm_source, utm_campaign, utm_content)
    encoded_message = URI.encode_www_form(message)
    "#{@whatsapp_base_url}?text=#{encoded_message}"
  end

  @doc """
  Builds the WhatsApp message with optional UTM context embedded in the text.
  This ensures gym staff see the lead source directly in the chat message.
  """
  def build_whatsapp_message(utm_source, utm_campaign, utm_content) do
    utm_parts =
      [
        if(utm_source, do: utm_source),
        if(utm_campaign, do: utm_campaign),
        if(utm_content, do: utm_content)
      ]
      |> Enum.filter(& &1)

    if utm_parts == [] do
      @whatsapp_message
    else
      "#{@whatsapp_message}\n📋 Source: #{Enum.join(utm_parts, " / ")}"
    end
  end
end
