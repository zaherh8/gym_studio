alias GymStudio.Repo
alias GymStudio.Progress.Exercise

IO.puts("Seeding exercises from free-exercise-db...")

json_path = Path.join(:code.priv_dir(:gym_studio), "repo/exercises.json")
exercises = json_path |> File.read!() |> Jason.decode!()

category_map = %{
  "strength" => "strength",
  "powerlifting" => "strength",
  "olympic weightlifting" => "strength",
  "strongman" => "strength",
  "cardio" => "cardio",
  "stretching" => "flexibility",
  "plyometrics" => "functional"
}

equipment_map = %{
  "body only" => "bodyweight",
  "bands" => "resistance_band",
  "kettlebells" => "kettlebell",
  "e-z curl bar" => "barbell",
  "foam roll" => "foam_roll",
  "exercise ball" => "exercise_ball",
  "medicine ball" => "medicine_ball"
}

tracking_type_map = %{
  "strength" => "weight_reps",
  "powerlifting" => "weight_reps",
  "olympic weightlifting" => "weight_reps",
  "strongman" => "weight_reps",
  "cardio" => "duration",
  "stretching" => "duration",
  "plyometrics" => "reps_only"
}

muscle_map = %{
  "lower back" => "lower_back",
  "middle back" => "middle_back"
}

now = DateTime.utc_now() |> DateTime.truncate(:second)

rows =
  exercises
  |> Enum.map(fn ex ->
    raw_category = ex["category"] || "strength"
    category = Map.get(category_map, raw_category, "strength")

    raw_equipment = ex["equipment"]

    equipment =
      cond do
        is_nil(raw_equipment) or raw_equipment == "None" -> nil
        Map.has_key?(equipment_map, raw_equipment) -> Map.get(equipment_map, raw_equipment)
        true -> String.downcase(raw_equipment) |> String.replace(" ", "_")
      end

    raw_muscle = List.first(ex["primaryMuscles"] || [])

    muscle_group =
      cond do
        is_nil(raw_muscle) -> nil
        Map.has_key?(muscle_map, raw_muscle) -> Map.get(muscle_map, raw_muscle)
        true -> String.downcase(raw_muscle) |> String.replace(" ", "_")
      end

    tracking_type = Map.get(tracking_type_map, raw_category, "weight_reps")

    description =
      case ex["instructions"] do
        list when is_list(list) and list != [] -> Enum.join(list, " ")
        _ -> nil
      end

    # Truncate name to 255 chars to avoid DB issues
    name = String.slice(ex["name"] || "Unknown", 0, 255)

    %{
      id: Ecto.UUID.generate(),
      name: name,
      category: category,
      muscle_group: muscle_group,
      equipment: equipment,
      tracking_type: tracking_type,
      description: description,
      is_custom: false,
      created_by_id: nil,
      inserted_at: now,
      updated_at: now
    }
  end)
  |> Enum.uniq_by(& &1.name)

# Insert in batches, skip conflicts
rows
|> Enum.chunk_every(100)
|> Enum.each(fn batch ->
  Repo.insert_all(Exercise, batch, on_conflict: :nothing, conflict_target: :name)
end)

IO.puts("  #{length(rows)} exercises seeded from free-exercise-db.")
