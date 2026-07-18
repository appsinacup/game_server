defmodule GameServerWeb.Api.V1.TournamentController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Tournaments
  alias GameServer.Tournaments.Tournament
  alias OpenApiSpex.Schema

  tags(["Tournaments"])

  @tournament_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      slug: %Schema{type: :string, description: "Shared across recurring occurrences"},
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
      recur: %Schema{type: :string, nullable: true, description: "Cron; nil = one-shot"},
      max_entries: %Schema{type: :integer, nullable: true},
      team_size: %Schema{type: :integer, description: "Advisory; enforced by game hooks"},
      bracket_size: %Schema{type: :integer},
      round_window_sec: %Schema{type: :integer},
      entry_count: %Schema{type: :integer},
      metadata: %Schema{type: :object}
    }
  }

  @match_schema %Schema{
    type: :object,
    nullable: true,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      bracket_index: %Schema{type: :integer},
      round: %Schema{type: :integer},
      slot: %Schema{type: :integer},
      a_leader_id: %Schema{type: :string, format: :uuid, nullable: true},
      b_leader_id: %Schema{type: :string, format: :uuid, nullable: true},
      winner_entry_id: %Schema{type: :string, format: :uuid, nullable: true},
      deadline: %Schema{type: :string, format: "date-time"},
      resolved_at: %Schema{type: :string, format: "date-time", nullable: true},
      metadata: %Schema{type: :object}
    }
  }

  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

  operation(:index,
    summary: "List tournaments",
    parameters: [
      state: [in: :query, schema: %Schema{type: :string}, description: "Filter by state"],
      category: [in: :query, schema: %Schema{type: :string}, description: "Filter by category"],
      slug: [in: :query, schema: %Schema{type: :string}, description: "Occurrence history"],
      page: [in: :query, schema: %Schema{type: :integer, default: 1}],
      page_size: [in: :query, schema: %Schema{type: :integer, default: 25}]
    ],
    responses: [
      ok:
        {"Tournaments", "application/json",
         %Schema{
           type: :object,
           properties: %{data: %Schema{type: :array, items: @tournament_schema}}
         }}
    ]
  )

  def index(conn, params) do
    page = max(parse_int(params["page"], 1), 1)
    page_size = min(max(parse_int(params["page_size"], 25), 1), 100)

    opts =
      [page: page, page_size: page_size]
      |> maybe_put(:state, params["state"])
      |> maybe_put(:category, params["category"])
      |> maybe_put(:slug, params["slug"])

    tournaments = Tournaments.list_tournaments(opts)
    total = Tournaments.count_tournaments(Keyword.drop(opts, [:page, :page_size]))

    json(conn, %{
      data: Enum.map(tournaments, &serialize_tournament/1),
      meta: %{page: page, page_size: page_size, total_count: total}
    })
  end

  operation(:show,
    summary: "Tournament details (with the caller's participation when authenticated)",
    parameters: [id: [in: :path, schema: %Schema{type: :string}, required: true]],
    responses: [
      ok: {"Tournament", "application/json", @tournament_schema},
      not_found: {"Not found", "application/json", @error_schema}
    ]
  )

  def show(conn, %{"id" => id}) do
    case fetch_tournament(id) do
      nil ->
        not_found(conn)

      tournament ->
        tournament = Tournaments.advance_lifecycle(tournament)

        entry =
          case current_user(conn) do
            nil -> nil
            user -> Tournaments.get_entry(tournament.id, user.id)
          end

        json(conn, %{
          data:
            tournament
            |> serialize_tournament()
            |> Map.put(:my_entry, entry && serialize_entry(entry))
        })
    end
  end

  operation(:join,
    summary: "Register as an entry leader",
    parameters: [id: [in: :path, schema: %Schema{type: :string}, required: true]],
    security: [%{"bearer" => []}],
    responses: [
      ok: {"Joined", "application/json", %Schema{type: :object}},
      bad_request: {"Rejected", "application/json", @error_schema}
    ]
  )

  def join(conn, %{"id" => id}) do
    with %Tournament{} = tournament <- fetch_tournament(id),
         {:ok, entry} <- Tournaments.join_tournament(current_user(conn), tournament) do
      json(conn, %{ok: true, entry: serialize_entry(entry)})
    else
      nil -> not_found(conn)
      {:error, reason} -> error(conn, reason)
    end
  end

  operation(:leave,
    summary: "Withdraw the caller's entry (before the draw)",
    parameters: [id: [in: :path, schema: %Schema{type: :string}, required: true]],
    security: [%{"bearer" => []}],
    responses: [
      ok: {"Left", "application/json", %Schema{type: :object}},
      bad_request: {"Rejected", "application/json", @error_schema}
    ]
  )

  def leave(conn, %{"id" => id}) do
    with %Tournament{} = tournament <- fetch_tournament(id),
         {:ok, _} <- Tournaments.leave_tournament(current_user(conn), tournament) do
      json(conn, %{ok: true})
    else
      nil -> not_found(conn)
      {:error, reason} -> error(conn, reason)
    end
  end

  operation(:standings,
    summary: "Placements, wins and champions",
    parameters: [id: [in: :path, schema: %Schema{type: :string}, required: true]],
    responses: [ok: {"Standings", "application/json", %Schema{type: :object}}]
  )

  def standings(conn, %{"id" => id}) do
    case fetch_tournament(id) do
      nil ->
        not_found(conn)

      tournament ->
        standings = Tournaments.standings(tournament)

        json(conn, %{
          data: %{
            champions: Enum.map(standings.champions, &serialize_entry/1),
            entries: standings.entries
          }
        })
    end
  end

  operation(:bracket,
    summary: "Brackets and matches",
    parameters: [id: [in: :path, schema: %Schema{type: :string}, required: true]],
    responses: [ok: {"Bracket", "application/json", %Schema{type: :object}}]
  )

  def bracket(conn, %{"id" => id}) do
    case fetch_tournament(id) do
      nil ->
        not_found(conn)

      tournament ->
        entries = Tournaments.list_entries(tournament.id)
        leaders = Map.new(entries, &{&1.id, &1.leader_id})

        json(conn, %{
          data: %{
            brackets:
              Enum.map(Tournaments.list_brackets(tournament.id), fn b ->
                %{index: b.index, size: b.size}
              end),
            entries: Enum.map(entries, &serialize_entry/1),
            matches:
              Enum.map(Tournaments.list_matches(tournament.id), &serialize_match(&1, leaders))
          }
        })
    end
  end

  operation(:my_match,
    summary: "The caller's current unresolved match, if any",
    parameters: [id: [in: :path, schema: %Schema{type: :string}, required: true]],
    security: [%{"bearer" => []}],
    responses: [ok: {"Match or null", "application/json", @match_schema}]
  )

  def my_match(conn, %{"id" => id}) do
    case fetch_tournament(id) do
      nil ->
        not_found(conn)

      tournament ->
        tournament = Tournaments.advance_lifecycle(tournament)

        case Tournaments.my_match(tournament, current_user(conn).id) do
          nil ->
            json(conn, %{data: nil})

          match ->
            entries = Tournaments.list_entries(tournament.id)
            leaders = Map.new(entries, &{&1.id, &1.leader_id})
            json(conn, %{data: serialize_match(match, leaders)})
        end
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  # Accepts a tournament id or a slug (current occurrence).
  defp fetch_tournament(id_or_slug) do
    case Ecto.UUID.cast(id_or_slug) do
      {:ok, _} -> Tournaments.get_tournament(id_or_slug)
      :error -> Tournaments.get_tournament_by_slug(id_or_slug)
    end
  end

  defp current_user(conn) do
    case conn.assigns[:current_scope] do
      %{user: user} -> user
      _ -> nil
    end
  end

  defp serialize_tournament(%Tournament{} = t) do
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
      entry_count: Tournaments.count_entries(t.id),
      metadata: t.metadata || %{}
    }
  end

  defp serialize_entry(entry) do
    %{
      id: entry.id,
      leader_id: entry.leader_id,
      seed: entry.seed,
      bracket_index: entry.bracket_index,
      wins: entry.wins,
      state: entry.state,
      metadata: entry.metadata || %{}
    }
  end

  defp serialize_match(match, leaders) do
    %{
      id: match.id,
      bracket_index: match.bracket_index,
      round: match.round,
      slot: match.slot,
      a_entry_id: match.a_entry_id,
      b_entry_id: match.b_entry_id,
      a_leader_id: leaders[match.a_entry_id],
      b_leader_id: leaders[match.b_entry_id],
      winner_entry_id: match.winner_entry_id,
      deadline: match.deadline,
      resolved_at: match.resolved_at,
      metadata: match.metadata || %{}
    }
  end

  defp not_found(conn) do
    conn |> put_status(:not_found) |> json(%{error: "not_found"})
  end

  defp error(conn, reason) when is_atom(reason) or is_binary(reason) do
    conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
  end

  defp error(conn, %Ecto.Changeset{} = changeset) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "invalid_data",
      errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
    })
  end

  defp error(conn, _reason) do
    conn |> put_status(:bad_request) |> json(%{error: "invalid_data"})
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_int(nil, default), do: default
  defp parse_int(value, _default) when is_integer(value), do: value

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end
end
