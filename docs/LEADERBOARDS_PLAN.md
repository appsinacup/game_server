# Leaderboards Implementation Plan

## Status: ✅ COMPLETED

> All phases have been implemented and tested. The leaderboard system is fully functional.

## Overview

A **server-authoritative** leaderboard system where each leaderboard is self-contained (can be permanent or time-limited). Simple 2-table design. Full stack: schema, context, API, admin UI, user UI, OpenAPI docs, and guide page.

---

## Database Schema

### `leaderboards`
| Column | Type | Description |
|--------|------|-------------|
| `id` | `string` (PK) | Unique ID (e.g., "weekly_kills_w48", "all_time_score") |
| `title` | `string` | Display name |
| `description` | `string` | Optional description |
| `sort_order` | `enum` | `:desc` (default) or `:asc` |
| `operator` | `enum` | `:set`, `:best`, `:incr`, `:decr` |
| `starts_at` | `utc_datetime` | When leaderboard started (nullable) |
| `ends_at` | `utc_datetime` | When leaderboard ended (nullable = active) |
| `metadata` | `map` | Extra data |
| `inserted_at` / `updated_at` | timestamps |

### `leaderboard_records`
| Column | Type | Description |
|--------|------|-------------|
| `id` | `bigint` (PK) | Auto-increment |
| `leaderboard_id` | `string` (FK) | References `leaderboards.id` |
| `user_id` | `bigint` (FK) | References `users.id` |
| `score` | `bigint` | Score value |
| `metadata` | `map` | Per-record metadata |
| `inserted_at` / `updated_at` | timestamps |

**Indexes:**
- Unique: `(leaderboard_id, user_id)`
- Index: `(leaderboard_id, score DESC)` and `(leaderboard_id, score ASC)`

---

## Implementation Phases

### Phase 1: Schema & Migration ✅
- [x] Create migration for `leaderboards` and `leaderboard_records`
- [x] Add enums for `sort_order` and `operator`

### Phase 2: Context Module ✅
- [x] `GameServer.Leaderboards` context with:
  - `create_leaderboard/1`, `update_leaderboard/2`, `delete_leaderboard/1`
  - `get_leaderboard/1`, `get_leaderboard!/1`
  - `list_leaderboards/1` (opts: `active: true/false`)
  - `submit_score/4` — server-only, handles operator logic
  - `list_records/2` — paginated with rank
  - `list_records_around_user/3` — centered on user
  - `get_user_record/2` — single user's record + rank
  - `delete_record/1`, `delete_user_record/2`

### Phase 3: API Controllers & Routes
- [ ] `LeaderboardController`:
  - `GET /api/v1/leaderboards` — list leaderboards
  - `GET /api/v1/leaderboards/:id` — get leaderboard
  - `GET /api/v1/leaderboards/:id/records` — list records
  - `GET /api/v1/leaderboards/:id/records/around/:user_id` — around user
  - `GET /api/v1/leaderboards/:id/records/me` — current user's record
- [ ] Add to router under `/api/v1`

### Phase 4: OpenAPI Documentation
- [ ] Add schemas: `Leaderboard`, `LeaderboardRecord`
- [ ] Document all endpoints with request/response examples

### Phase 5: Admin UI
- [ ] `AdminLive.Leaderboards` LiveView:
  - List all leaderboards (with filters: active/ended)
  - Create/Edit/Delete leaderboards
  - View records for a leaderboard
  - Manually add/edit/delete records
  - End a leaderboard (set `ends_at`)
- [ ] Add link in admin index page

### Phase 6: User UI
- [ ] Add "Leaderboards" button in header (next to Settings/Logout)
- [ ] `LeaderboardsLive` page:
  - List active leaderboards
  - Click to view records
  - Show current user's rank highlighted
  - Pagination
- [ ] Route: `/leaderboards` and `/leaderboards/:id`

### Phase 7: Guide Page
- [ ] Add leaderboards section to `/docs/guide`:
  - How leaderboards work
  - Server-only score submission
  - API endpoints
  - Example code (Elixir, Godot)

### Phase 8: Tests
- [ ] Context unit tests (`leaderboards_test.exs`)
- [ ] API controller tests (`leaderboard_controller_test.exs`)
- [ ] Admin LiveView tests (`admin_live/leaderboards_test.exs`)
- [ ] User LiveView tests (`leaderboards_live_test.exs`)

---

## API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/api/v1/leaderboards` | Optional | List leaderboards |
| `GET` | `/api/v1/leaderboards/:id` | Optional | Get leaderboard details |
| `GET` | `/api/v1/leaderboards/:id/records` | Optional | List records (paginated) |
| `GET` | `/api/v1/leaderboards/:id/records/around/:user_id` | Required | Records around user |
| `GET` | `/api/v1/leaderboards/:id/records/me` | Required | Current user's record + rank |

**Query params:**
- `active` — `true`/`false` to filter by ended status
- `limit` — page size (default 25, max 100)
- `page` — page number

**Response format (list records):**
```json
{
  "data": [
    {
      "rank": 1,
      "user_id": 123,
      "display_name": "PlayerOne",
      "score": 5000,
      "metadata": {},
      "updated_at": "2025-12-01T10:00:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "page_size": 25,
    "total_count": 150,
    "total_pages": 6,
    "has_more": true
  }
}
```

---

## Server-Side Functions

```elixir
# Create leaderboard
Leaderboards.create_leaderboard(%{
  id: "weekly_kills_w49",
  title: "Weekly Kills - Week 49",
  sort_order: :desc,
  operator: :incr,
  starts_at: ~U[2025-12-02 00:00:00Z]
})

# Submit score (server-only)
Leaderboards.submit_score("weekly_kills_w49", user_id, 10, %{weapon: "sword"})

# End leaderboard
Leaderboards.end_leaderboard("weekly_kills_w49")

# List active leaderboards
Leaderboards.list_leaderboards(active: true)

# Get records with rank
Leaderboards.list_records("weekly_kills_w49", page: 1, limit: 25)

# Get user's rank
Leaderboards.get_user_record("weekly_kills_w49", user_id)
```

---

## UI Mockups

### Header (logged in user)
```
[Logo]                    [Leaderboards] [Settings] [Log out]
```

### Leaderboards Page (`/leaderboards`)
```
┌─────────────────────────────────────────────────────────┐
│  Leaderboards                                           │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────┐   │
│  │ Weekly Kills - Week 49              🟢 Active   │   │
│  │ Ends: Dec 9, 2025                   [View →]    │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ All-Time High Score                 🟢 Active   │   │
│  │ Permanent                           [View →]    │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Weekly Kills - Week 48              ⚫ Ended    │   │
│  │ Ended: Dec 2, 2025                  [View →]    │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Leaderboard Detail (`/leaderboards/:id`)
```
┌─────────────────────────────────────────────────────────┐
│  ← Back    Weekly Kills - Week 49                       │
│            🟢 Active | Ends Dec 9, 2025                 │
├─────────────────────────────────────────────────────────┤
│  Your Rank: #5 (1,250 pts)                              │
├──────┬──────────────────┬───────────┬──────────────────┤
│ Rank │ Player           │ Score     │ Updated          │
├──────┼──────────────────┼───────────┼──────────────────┤
│ 1    │ ProGamer123      │ 5,000     │ 2 hours ago      │
│ 2    │ NinjaKiller      │ 4,200     │ 1 hour ago       │
│ 3    │ SwordMaster      │ 3,800     │ 30 min ago       │
│ 4    │ DragonSlayer     │ 1,500     │ 5 hours ago      │
│ 5    │ **You**          │ **1,250** │ 10 min ago       │  ← highlighted
│ 6    │ CoolPlayer       │ 1,100     │ 3 hours ago      │
├──────┴──────────────────┴───────────┴──────────────────┤
│                [Prev] Page 1/6 [Next]                   │
└─────────────────────────────────────────────────────────┘
```

### Admin UI (`/admin/leaderboards`)
```
┌─────────────────────────────────────────────────────────┐
│  ← Back to Admin    Leaderboards (5)    [+ Create]     │
├─────────────────────────────────────────────────────────┤
│  Filter: [All ▼] [Active ▼] [Ended ▼]                  │
├──────┬────────────────────┬────────┬────────┬──────────┤
│ ID   │ Title              │ Status │ Records│ Actions  │
├──────┼────────────────────┼────────┼────────┼──────────┤
│ w_49 │ Weekly Kills W49   │ Active │ 150    │ [Edit]   │
│      │                    │        │        │ [Records]│
│      │                    │        │        │ [End]    │
├──────┼────────────────────┼────────┼────────┼──────────┤
│ all  │ All-Time Score     │ Active │ 1,234  │ [Edit]   │
│      │                    │        │        │ [Records]│
└──────┴────────────────────┴────────┴────────┴──────────┘
```

---

## Files to Create/Modify

### New Files
```
lib/game_server/leaderboards.ex                      # Context
lib/game_server/leaderboards/leaderboard.ex          # Schema
lib/game_server/leaderboards/record.ex               # Schema

lib/game_server_web/controllers/api/v1/leaderboard_controller.ex
lib/game_server_web/live/leaderboards_live.ex        # User UI
lib/game_server_web/live/admin_live/leaderboards.ex  # Admin UI

priv/repo/migrations/XXXX_create_leaderboards.exs

test/game_server/leaderboards_test.exs
test/game_server_web/controllers/api/v1/leaderboard_controller_test.exs
test/game_server_web/live/leaderboards_live_test.exs
test/game_server_web/live/admin_live/leaderboards_test.exs
test/support/fixtures/leaderboards_fixtures.ex
```

### Modified Files
```
lib/game_server_web/router.ex                        # Add routes
lib/game_server_web/components/layouts/app.html.heex # Add header button
lib/game_server_web/live/admin_live/index.ex         # Add link
lib/game_server_web/live/public_docs/guide.html.heex # Add section
lib/game_server_web/controllers/api/v1/open_api.ex   # Add schemas
```

---

## Execution Order

1. **Phase 1-2**: Schema + Context (foundation)
2. **Phase 3-4**: API + OpenAPI (backend complete)
3. **Phase 5**: Admin UI (management)
4. **Phase 6**: User UI (public facing)
5. **Phase 7**: Guide page (docs)
6. **Phase 8**: Tests (throughout)

---

## Progress Tracking

### Phase 1: Schema & Migration
- [ ] Migration created
- [ ] Schemas created

### Phase 2: Context Module
- [ ] Leaderboard CRUD
- [ ] Record CRUD
- [ ] submit_score with operator logic
- [ ] list_records with rank
- [ ] list_records_around_user
- [ ] get_user_record

### Phase 3: API Controllers
- [ ] LeaderboardController created
- [ ] Routes added

### Phase 4: OpenAPI
- [ ] Schemas added
- [ ] Endpoints documented

### Phase 5: Admin UI
- [ ] LiveView created
- [ ] Link in admin index

### Phase 6: User UI
- [ ] Header button added
- [ ] LeaderboardsLive created
- [ ] Routes added

### Phase 7: Guide Page
- [ ] Section added

### Phase 8: Tests
- [ ] Context tests
- [ ] Controller tests
- [ ] LiveView tests
