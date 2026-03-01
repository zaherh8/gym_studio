defmodule GymStudio.SchedulingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `GymStudio.Scheduling` context.
  """

  alias GymStudio.Scheduling

  @doc """
  Generate a training session.

  ## Options
  - `:client_id` - Required. The ID of the client booking the session.
  - `:trainer_id` - Optional. The ID of the trainer (for approved sessions).
  - `:scheduled_at` - Optional. Defaults to tomorrow at 10:00 UTC.
  - `:duration_minutes` - Optional. Defaults to 60.
  - `:status` - Optional. Defaults to "pending".
  - `:notes` - Optional. Client notes.

  ## Examples

      iex> training_session_fixture(%{client_id: client.id})
      %TrainingSession{}

      iex> training_session_fixture(%{client_id: client.id, status: "confirmed", trainer_id: trainer.id})
      %TrainingSession{}
  """
  def training_session_fixture(attrs \\ %{}) do
    scheduled_at =
      attrs[:scheduled_at] ||
        DateTime.utc_now()
        |> DateTime.add(1, :day)
        |> DateTime.add(System.unique_integer([:positive, :monotonic]), :second)
        |> DateTime.truncate(:second)

    base_attrs = %{
      scheduled_at: scheduled_at,
      duration_minutes: 60,
      notes: "Test session notes"
    }

    attrs = Map.merge(base_attrs, Enum.into(attrs, %{}))

    # If status is provided and not "pending", or if trainer_id is provided,
    # we need to insert directly to bypass validations
    if Map.get(attrs, :status) in ["confirmed", "completed", "cancelled"] or
         Map.has_key?(attrs, :trainer_id) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      session_attrs =
        attrs
        |> Map.put(:inserted_at, now)
        |> Map.put(:updated_at, now)

      %Scheduling.TrainingSession{}
      |> Ecto.Changeset.change(session_attrs)
      |> GymStudio.Repo.insert!()
    else
      {:ok, session} = Scheduling.book_session(attrs)
      session
    end
  end

  @doc """
  Generate a confirmed training session with a trainer assigned.

  ## Options
  - `:client_id` - Required. The ID of the client.
  - `:trainer_id` - Required. The ID of the trainer.
  - `:approved_by_id` - Required. The ID of the user who approved it.
  - `:scheduled_at` - Optional. Defaults to tomorrow at 10:00 UTC.
  - `:duration_minutes` - Optional. Defaults to 60.

  ## Examples

      iex> confirmed_session_fixture(%{
      ...>   client_id: client.id,
      ...>   trainer_id: trainer.id,
      ...>   approved_by_id: admin.id
      ...> })
      %TrainingSession{}
  """
  def confirmed_session_fixture(attrs) do
    trainer_id = Map.fetch!(attrs, :trainer_id)
    approved_by_id = Map.fetch!(attrs, :approved_by_id)

    session = training_session_fixture(Map.drop(attrs, [:trainer_id, :approved_by_id]))

    {:ok, session} = Scheduling.approve_session(session, trainer_id, approved_by_id)

    session
  end

  @doc """
  Generate a time slot.

  ## Options
  - `:day_of_week` - Optional. Defaults to 1 (Monday).
  - `:start_time` - Optional. Defaults to 09:00:00.
  - `:end_time` - Optional. Defaults to 10:00:00.
  - `:active` - Optional. Defaults to true.

  ## Examples

      iex> time_slot_fixture()
      %TimeSlot{}

      iex> time_slot_fixture(%{day_of_week: 3, start_time: ~T[14:00:00], end_time: ~T[15:00:00]})
      %TimeSlot{}
  """
  def time_slot_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        day_of_week: 1,
        start_time: ~T[09:00:00],
        end_time: ~T[10:00:00],
        active: true
      })

    {:ok, time_slot} = Scheduling.create_time_slot(attrs)

    time_slot
  end
end
