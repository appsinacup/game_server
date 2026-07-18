defmodule GameServerWeb.Api.V1.MatchmakingController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Matchmaking
  alias OpenApiSpex.Schema

  tags(["Matchmaking"])

  @ticket_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      status: %Schema{type: :string, enum: ["queued", "matched", "cancelled"]},
      match_params: %Schema{
        type: :object,
        description: "String key/value pairs; only identical params match together"
      },
      min_players: %Schema{type: :integer},
      max_players: %Schema{type: :integer},
      timeout_ms: %Schema{type: :integer},
      queued_at: %Schema{type: :string, format: "date-time"},
      matched_at: %Schema{type: :string, format: "date-time", nullable: true},
      match_id: %Schema{
        type: :string,
        format: :uuid,
        nullable: true,
        description: "Lobby the ticket was matched into"
      }
    }
  }

  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

  operation(:create,
    operation_id: "matchmaking_join",
    summary: "Join the matchmaking queue",
    description: """
    Creates a matchmaking ticket for the caller. Tickets with identical
    match_params are grouped; when enough are queued the server creates a
    hidden lobby and pushes a `matchmaking_found` event on the caller's user
    channel. Keep a socket connected while queued — a player who stays offline
    past the grace period is dropped from the queue by the sweep.

    A caller in a party queues the whole party: one ticket per member, matched
    as an indivisible unit. Returns `409` with `not_party_leader` when a member
    rather than the leader calls this, `party_too_large` when the party cannot
    fit in `max_players`, and `already_queued` when the caller or any member is
    already in the queue.
    """,
    security: [%{"bearer" => []}],
    request_body:
      {"Ticket", "application/json",
       %Schema{
         type: :object,
         properties: %{
           match_params: %Schema{type: :object},
           min_players: %Schema{type: :integer},
           max_players: %Schema{type: :integer}
         }
       }},
    responses: [
      created:
        {"Ticket", "application/json",
         %Schema{type: :object, properties: %{data: @ticket_schema}}},
      conflict: {"Cannot queue right now", "application/json", @error_schema},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      unprocessable_entity: {"Validation failed", "application/json", %Schema{type: :object}}
    ]
  )

  def create(conn, params) do
    user = conn.assigns.current_scope.user

    case Matchmaking.join(
           user,
           Map.get(params, "match_params", %{}),
           parse_optional_int(params["min_players"]),
           parse_optional_int(params["max_players"])
         ) do
      {:ok, ticket} ->
        conn
        |> put_status(:created)
        |> json(%{data: serialize(ticket)})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:conflict)
        |> json(%{error: Atom.to_string(reason)})

      {:error, changeset} ->
        changeset_error(conn, changeset)
    end
  end

  operation(:delete,
    operation_id: "matchmaking_cancel",
    summary: "Leave the matchmaking queue",
    description: "Cancels all of the caller's queued tickets.",
    security: [%{"bearer" => []}],
    responses: [
      ok:
        {"Cancelled", "application/json",
         %Schema{type: :object, properties: %{data: %Schema{type: :object}}}},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  def delete(conn, _params) do
    cancelled = Matchmaking.cancel(conn.assigns.current_scope.user.id)
    json(conn, %{data: %{cancelled: cancelled}})
  end

  operation(:me,
    operation_id: "matchmaking_my_ticket",
    summary: "Get my current ticket",
    description: "The caller's queued ticket, or null when not in the queue.",
    security: [%{"bearer" => []}],
    responses: [
      ok:
        {"Ticket", "application/json",
         %Schema{
           type: :object,
           properties: %{data: %Schema{@ticket_schema | nullable: true}}
         }},
      unauthorized: {"Not authenticated", "application/json", @error_schema}
    ]
  )

  def me(conn, _params) do
    case Matchmaking.current_ticket(conn.assigns.current_scope.user.id) do
      nil -> json(conn, %{data: nil})
      ticket -> json(conn, %{data: serialize(ticket)})
    end
  end

  operation(:stats,
    operation_id: "matchmaking_stats",
    summary: "Queue statistics",
    description: "Waiting-player depth per match_params group.",
    security: [%{"bearer" => []}],
    responses: [
      ok:
        {"Stats", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{
               type: :object,
               properties: %{
                 queued: %Schema{type: :integer},
                 queues: %Schema{
                   type: :array,
                   items: %Schema{
                     type: :object,
                     properties: %{
                       params: %Schema{type: :object},
                       waiting: %Schema{type: :integer}
                     }
                   }
                 }
               }
             }
           }
         }}
    ]
  )

  def stats(conn, _params) do
    stats = Matchmaking.stats()
    # Public view: queue depths only, not lifetime matched/cancelled counters.
    json(conn, %{data: %{queued: stats.queued, queues: stats.queues}})
  end

  # ── helpers ───────────────────────────────────────────────────────────────

  defp serialize(ticket) do
    %{
      id: ticket.id,
      status: ticket.status,
      match_params: ticket.match_params,
      min_players: ticket.min_players,
      max_players: ticket.max_players,
      timeout_ms: ticket.timeout_ms,
      queued_at: ticket.queued_at,
      matched_at: ticket.matched_at,
      match_id: ticket.match_id
    }
  end

  defp parse_optional_int(value) when is_integer(value), do: value

  defp parse_optional_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_optional_int(_value), do: nil

  defp changeset_error(conn, changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: "invalid_data",
      errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    })
  end
end
