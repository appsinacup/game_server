defmodule GameServerWeb.Api.V1.Admin.TournamentController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Tournaments
  alias GameServer.Tournaments.Tournament
  alias OpenApiSpex.Schema

  tags(["Admin – Tournaments"])

  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

  @tournament_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      slug: %Schema{type: :string},
      title: %Schema{type: :string},
      description: %Schema{type: :string},
      category: %Schema{type: :string, nullable: true},
      state: %Schema{
        type: :string,
        enum: ["scheduled", "registration", "running", "finished", "cancelled"]
      },
      registration_opens_at: %Schema{type: :string, format: "date-time", nullable: true},
      starts_at: %Schema{type: :string, format: "date-time"},
      ends_at: %Schema{type: :string, format: "date-time", nullable: true},
      recur: %Schema{type: :string, nullable: true},
      max_entries: %Schema{type: :integer, nullable: true},
      team_size: %Schema{type: :integer},
      bracket_size: %Schema{type: :integer},
      round_window_sec: %Schema{type: :integer},
      deadline_policy: %Schema{
        type: :string,
        enum: ["forfeit_both", "advance_first_slot", "random"]
      },
      metadata: %Schema{type: :object},
      inserted_at: %Schema{type: :string, format: "date-time"},
      updated_at: %Schema{type: :string, format: "date-time"}
    }
  }

  @tournament_body %Schema{
    type: :object,
    properties: %{
      slug: %Schema{type: :string},
      title: %Schema{type: :string},
      description: %Schema{type: :string},
      category: %Schema{type: :string},
      registration_opens_at: %Schema{type: :string, format: "date-time"},
      starts_at: %Schema{type: :string, format: "date-time"},
      ends_at: %Schema{type: :string, format: "date-time"},
      recur: %Schema{type: :string, description: "Cron expression; omit for one-shot"},
      max_entries: %Schema{type: :integer},
      team_size: %Schema{type: :integer},
      bracket_size: %Schema{type: :integer, description: "Power of two >= 2"},
      round_window_sec: %Schema{type: :integer},
      deadline_policy: %Schema{
        type: :string,
        enum: ["forfeit_both", "advance_first_slot", "random"]
      },
      metadata: %Schema{type: :object}
    },
    required: [:slug, :title, :starts_at, :round_window_sec]
  }

  operation(:create,
    operation_id: "admin_create_tournament",
    summary: "Create tournament (admin)",
    security: [%{"authorization" => []}],
    request_body: {"Tournament", "application/json", @tournament_body},
    responses: [
      ok:
        {"Tournament", "application/json",
         %Schema{type: :object, properties: %{data: @tournament_schema}}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema},
      unprocessable_entity: {"Validation failed", "application/json", %Schema{type: :object}}
    ]
  )

  def create(conn, params) do
    case Tournaments.create_tournament(params) do
      {:ok, tournament} -> json(conn, %{data: serialize(tournament)})
      {:error, changeset} -> changeset_error(conn, changeset)
    end
  end

  operation(:update,
    operation_id: "admin_update_tournament",
    summary: "Update tournament (admin)",
    security: [%{"authorization" => []}],
    parameters: [id: [in: :path, schema: %Schema{type: :string}, required: true]],
    request_body: {"Fields to change", "application/json", @tournament_body},
    responses: [
      ok:
        {"Tournament", "application/json",
         %Schema{type: :object, properties: %{data: @tournament_schema}}},
      not_found: {"Not found", "application/json", @error_schema},
      unprocessable_entity: {"Validation failed", "application/json", %Schema{type: :object}}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    with_tournament(conn, id, fn tournament ->
      case Tournaments.update_tournament(tournament, Map.delete(params, "id")) do
        {:ok, tournament} -> json(conn, %{data: serialize(tournament)})
        {:error, changeset} -> changeset_error(conn, changeset)
      end
    end)
  end

  operation(:delete,
    operation_id: "admin_delete_tournament",
    summary: "Delete tournament and all its entries/matches (admin)",
    security: [%{"authorization" => []}],
    parameters: [id: [in: :path, schema: %Schema{type: :string}, required: true]],
    responses: [
      ok: {"Deleted", "application/json", %Schema{type: :object}},
      not_found: {"Not found", "application/json", @error_schema}
    ]
  )

  def delete(conn, %{"id" => id}) do
    with_tournament(conn, id, fn tournament ->
      {:ok, _} = Tournaments.delete_tournament(tournament)
      json(conn, %{ok: true})
    end)
  end

  operation(:cancel,
    operation_id: "admin_cancel_tournament",
    summary: "Cancel tournament (admin; terminal, no recurrence spawn)",
    security: [%{"authorization" => []}],
    parameters: [id: [in: :path, schema: %Schema{type: :string}, required: true]],
    responses: [
      ok:
        {"Tournament", "application/json",
         %Schema{type: :object, properties: %{data: @tournament_schema}}},
      not_found: {"Not found", "application/json", @error_schema}
    ]
  )

  def cancel(conn, %{"id" => id}) do
    with_tournament(conn, id, fn tournament ->
      {:ok, tournament} = Tournaments.cancel_tournament(tournament)
      json(conn, %{data: serialize(tournament)})
    end)
  end

  operation(:draw,
    operation_id: "admin_draw_tournament",
    summary: "Draw the bracket now (admin; pulls starts_at to now)",
    security: [%{"authorization" => []}],
    parameters: [id: [in: :path, schema: %Schema{type: :string}, required: true]],
    responses: [
      ok:
        {"Tournament", "application/json",
         %Schema{type: :object, properties: %{data: @tournament_schema}}},
      bad_request: {"Not in a drawable state", "application/json", @error_schema},
      not_found: {"Not found", "application/json", @error_schema}
    ]
  )

  def draw(conn, %{"id" => id}) do
    with_tournament(conn, id, fn tournament ->
      if tournament.state in ["scheduled", "registration"] do
        {:ok, tournament} =
          Tournaments.update_tournament(tournament, %{starts_at: DateTime.utc_now(:second)})

        json(conn, %{data: serialize(Tournaments.advance_lifecycle(tournament))})
      else
        conn |> put_status(:bad_request) |> json(%{error: "not_drawable"})
      end
    end)
  end

  operation(:finish,
    operation_id: "admin_finish_tournament",
    summary: "Finish tournament now (admin; pulls ends_at to now)",
    security: [%{"authorization" => []}],
    parameters: [id: [in: :path, schema: %Schema{type: :string}, required: true]],
    responses: [
      ok:
        {"Tournament", "application/json",
         %Schema{type: :object, properties: %{data: @tournament_schema}}},
      bad_request: {"Not running", "application/json", @error_schema},
      not_found: {"Not found", "application/json", @error_schema}
    ]
  )

  def finish(conn, %{"id" => id}) do
    with_tournament(conn, id, fn tournament ->
      if tournament.state == "running" do
        {:ok, tournament} =
          Tournaments.update_tournament(tournament, %{ends_at: DateTime.utc_now(:second)})

        json(conn, %{data: serialize(Tournaments.advance_lifecycle(tournament))})
      else
        conn |> put_status(:bad_request) |> json(%{error: "not_running"})
      end
    end)
  end

  operation(:resolve_match,
    operation_id: "admin_resolve_tournament_match",
    summary: "Force a match verdict (admin)",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :string}, required: true],
      match_id: [in: :path, schema: %Schema{type: :string}, required: true]
    ],
    request_body: {
      "Verdict",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          winner_entry_id: %Schema{
            type: :string,
            format: :uuid,
            nullable: true,
            description: "Omit or null for :no_winner (double forfeit)"
          }
        }
      }
    },
    responses: [
      ok: {"Resolved", "application/json", %Schema{type: :object}},
      bad_request:
        {"Rejected (already resolved / invalid winner)", "application/json", @error_schema},
      not_found: {"Not found", "application/json", @error_schema}
    ]
  )

  def resolve_match(conn, %{"id" => id, "match_id" => match_id} = params) do
    with_tournament(conn, id, fn tournament ->
      verdict =
        case params["winner_entry_id"] do
          winner when is_binary(winner) and winner != "" -> winner
          _ -> :no_winner
        end

      match = Tournaments.get_match(match_id)

      if match == nil or match.tournament_id != tournament.id do
        conn |> put_status(:not_found) |> json(%{error: "not_found"})
      else
        case Tournaments.resolve_match(match_id, verdict) do
          {:ok, match} ->
            json(conn, %{ok: true, winner_entry_id: match.winner_entry_id})

          {:error, reason} ->
            conn |> put_status(:bad_request) |> json(%{error: to_string_reason(reason)})
        end
      end
    end)
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp with_tournament(conn, id, fun) do
    case Tournaments.get_tournament(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
      tournament -> fun.(tournament)
    end
  end

  defp serialize(%Tournament{} = t) do
    %{
      id: t.id,
      slug: t.slug,
      title: t.title,
      description: t.description,
      category: t.category,
      state: t.state,
      registration_opens_at: t.registration_opens_at,
      starts_at: t.starts_at,
      ends_at: t.ends_at,
      recur: t.recur,
      max_entries: t.max_entries,
      team_size: t.team_size,
      bracket_size: t.bracket_size,
      round_window_sec: t.round_window_sec,
      deadline_policy: t.deadline_policy,
      metadata: t.metadata || %{},
      inserted_at: t.inserted_at,
      updated_at: t.updated_at
    }
  end

  defp changeset_error(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: "invalid_data",
      errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    })
  end

  defp to_string_reason(reason) when is_atom(reason) or is_binary(reason),
    do: to_string(reason)

  defp to_string_reason(_reason), do: "invalid_data"
end
