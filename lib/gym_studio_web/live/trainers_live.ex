defmodule GymStudioWeb.TrainersLive do
  @moduledoc """
  Public page showcasing the gym's personal trainers.
  """
  use GymStudioWeb, :live_view

  alias GymStudio.Accounts

  @impl true
  def mount(_params, _session, socket) do
    trainers = Accounts.list_trainers(status: "approved")

    {:ok, assign(socket, trainers: trainers, page_title: "Our Trainers")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <%!-- Hero Section --%>
      <section class="py-20 bg-base-200">
        <div class="container mx-auto px-4 text-center">
          <h1 class="text-4xl md:text-5xl font-bold mb-4">
            Meet Our <span class="text-primary">Trainers</span>
          </h1>
          <p class="text-xl text-base-content/70 max-w-2xl mx-auto">
            Our certified personal trainers are dedicated to helping you achieve your fitness goals.
          </p>
        </div>
      </section>

      <%!-- Trainers Grid --%>
      <section class="py-16">
        <div class="container mx-auto px-4">
          <%= if Enum.empty?(@trainers) do %>
            <div class="text-center py-12">
              <p class="text-xl text-base-content/70">
                Our trainer profiles are coming soon. Check back later!
              </p>
            </div>
          <% else %>
            <div class="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
              <%= for trainer <- @trainers do %>
                <div class="card bg-base-200 shadow-xl">
                  <figure class="px-10 pt-10">
                    <div class="avatar placeholder">
                      <div class="bg-primary text-primary-content rounded-full w-32">
                        <span class="text-3xl">
                          {String.first(trainer.user.name || trainer.user.email) |> String.upcase()}
                        </span>
                      </div>
                    </div>
                  </figure>
                  <div class="card-body items-center text-center">
                    <h2 class="card-title">{trainer.user.name || trainer.user.email}</h2>
                    <%= if trainer.bio do %>
                      <p class="text-base-content/70">{trainer.bio}</p>
                    <% end %>
                    <%= if trainer.specializations && length(trainer.specializations) > 0 do %>
                      <div class="flex flex-wrap gap-2 mt-2">
                        <%= for spec <- trainer.specializations do %>
                          <span class="badge badge-primary badge-outline">{spec}</span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </section>

      <%!-- CTA Section --%>
      <section class="py-16 bg-primary text-primary-content">
        <div class="container mx-auto px-4 text-center">
          <h2 class="text-3xl font-bold mb-4">Ready to Train?</h2>
          <p class="text-xl opacity-90 mb-8">
            Sign up today and get matched with the perfect trainer for your goals.
          </p>
          <a href={~p"/users/register"} class="btn btn-secondary btn-lg">
            Get Started
          </a>
        </div>
      </section>
    </div>
    """
  end
end
