defmodule GameServerWeb.ApiSpec do
  @moduledoc """
  OpenAPI specification for the Game Server API.
  """

  alias GameServerWeb.{Endpoint, Router}
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server, Tag}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "Game Server API",
        version: api_version(),
        description: """
        API for the Gamend Game Server. Provides HTTP REST API, real-time WebSocket channels, and WebRTC DataChannels for low-latency game data. Features authentication, users, lobbies, groups, parties, friends, chat, notifications, achievements, leaderboards, server scripting, and admin portal.

        ## **1. Authentication**

        This API uses JWT (JSON Web Tokens) with access and refresh tokens:

        ### **1.1 Getting Tokens**
        - **Email/Password**: POST to `/api/v1/login` with email and password
        - **Device (SDK)**: POST to `/api/v1/login` with a `device_id` string (creates/returns a device user)
        - **Discord OAuth**: Use `/api/v1/auth/discord` flow
        - **Google OAuth**: Use `/api/v1/auth/google` flow
        - **Facebook OAuth**: Use `/api/v1/auth/facebook` flow
        - **Apple Sign In**: Use `/auth/apple` browser flow or apple sdk flow
        - **Steam (OpenID)**: Use `/api/v1/auth/steam` flow

        Both methods return:
        - `access_token` - Short-lived (15 min), use for API requests
        - `refresh_token` - Long-lived (30 days), use to get new access tokens

        ### **1.2 Using Tokens**
        Include the access token in the Authorization header:
        ```
        Authorization: Bearer <access_token>
        ```

        ### **1.3 Refreshing Tokens**
        When your access token expires, use POST `/api/v1/refresh` with your refresh token to get a new access token.

        ## **2. Users**
        Users endpoints cover the user lifecycle and profile features. Key highlights:

        - **Registration and login** (email/password, device token for SDKs, and OAuth providers)
        - **Profile metadata** (JSON blob per user) and editable profile fields
        - **Account lifecycle**: password reset, email confirmation, and account deletion
        - **Sessions & tokens**: both browser sessions and JWT-based API tokens are supported

        ## **3. Friends**
        The Friends domain offers lightweight social features:

        - **Friend requests** (send / accept / reject / block flows)
        - **Friend listing & pagination**, with basic privacy controls
        - **Domain helpers** to manage and query friend relationships from API or UI contexts

        ## **4. Lobbies**
        Lobbies provide matchmaking / room management primitives. Highlights:

        - **Create / list / update / delete** lobbies with rich metadata (mode, region, tags)
        - **Host-managed or hostless** modes (hostless allowed internally, not creatable via public API)
        - **Membership management**: join, leave, kick users, and automatic host transfer
        - **Controls & protection**: max users, hidden/locked states, and optional password protection
        - **Hidden lobbies** are excluded from public listings; public listing endpoints are paginated

        ## **5. Notifications**
        Persistent user-to-user notifications that survive across sessions:

        - **Send notifications** to accepted friends with a title, optional content, and optional metadata
        - **List own notifications** with pagination (ordered oldest-first)
        - **Delete notifications** by ID (single or batch)
        - **Real-time delivery** via the user WebSocket channel (`"notification"` events)
        - **Offline delivery**: undeleted notifications are replayed on WebSocket reconnect

        ## **6. Groups**
        Groups provide persistent community management for players:

        - **Three group types**: `public` (anyone joins directly), `private` (users request to join, admins approve), `hidden` (invite-only, never listed)
        - **Membership roles**: `admin` and `member`, with promote/demote capabilities
        - **Join requests**: for private groups, users submit requests that admins approve or reject
        - **Invitations**: admins can invite users directly (blocked users are rejected)
        - **CRUD operations**: create, update, delete groups with metadata support
        - **Group chat**: integrated via the Chat API with `chat_type: "group"`

        ## **7. Parties**
        Ephemeral groups of users for short-lived sessions (e.g., matchmaking squads):

        - **Invite-only joining**: the party leader sends invites by user ID to friends or shared-group members
        - **Invite flow**: `POST /parties/invite` → recipient accepts via `POST /parties/invite/accept` or declines via `POST /parties/invite/decline`; leader can cancel via `POST /parties/invite/cancel`
        - **Invite visibility**: leader can list sent invites (`GET /parties/invitations/sent`); recipient can list received invites (`GET /parties/invitations`)
        - **Connection requirement**: invites can only be sent to users who are friends or share at least one group with the leader
        - **One party at a time**: a user can only be in one party; accepting an invite while already in a party is rejected
        - **Leader management**: the creator is the leader; leadership can be transferred
        - **Lobby integration**: parties can create or join lobbies as a group
        - **Party chat**: integrated via the Chat API with `chat_type: "party"`
        - **Real-time events** via the party WebSocket channel

        ## **8. Chat**
        Real-time messaging across multiple conversation types:

        - **Chat types**: `lobby` (within a lobby), `group` (within a group), `party` (within a party), `friend` (DMs between friends)
        - **Send messages** with content, optional metadata, and automatic access validation
        - **List messages** with pagination (newest first)
        - **Read tracking**: mark messages as read and get unread counts per conversation
        - **Real-time delivery** via PubSub and WebSocket channels
        - **Moderation hooks**: `before_chat_message` pipeline hook for filtering/blocking

        ## **9. Leaderboards**
        Server-managed ranked scoreboards:

        - **Multiple leaderboards**: create named leaderboards with configurable sort order
        - **Score submission**: submit scores with optional metadata
        - **Rankings**: retrieve paginated rankings with user details
        - **Reset support**: leaderboards can be reset periodically

        ## **10. Key-Value Storage**
        Per-user persistent key-value storage for game state, preferences, and settings:

        - **Get/set/delete** key-value pairs scoped to the authenticated user
        - **List keys** with optional prefix filtering
        - **Metadata support**: values can include arbitrary JSON metadata

        ## **11. Achievements**
        Track player accomplishments with progress-based or instant-unlock achievements:

        - **Achievement definitions**: admin-created with slug, title, description, icon, sort order, and optional progress target
        - **Progress tracking**: increment progress toward a target; auto-unlocks when progress reaches the target
        - **Instant unlock**: directly unlock achievements without progress tracking
        - **Hidden achievements**: details obscured ("???") until unlocked by the user
        - **Public listings**: paginated, optionally filtered; authenticated users see their own progress
        - **Admin management**: create, update, delete, grant, revoke, unlock, and increment achievements

        ## **12. Real-time: WebSocket Channels**
        The server provides real-time communication via Phoenix WebSocket channels. Connect to the WebSocket endpoint and join topic-based channels for live updates.

        ### **12.1 Connection**
        Connect to `wss://your-server.com/socket` with your JWT token as a parameter:
        ```
        const socket = new Socket("wss://your-server.com/socket", { params: { token: "<access_token>" } })
        socket.connect()
        ```

        ### **12.2 Available Channels**
        - **User channel** (`user:<user_id>`): notifications, friend events, achievement unlocks, party/group invites
        - **Lobby channel** (`lobby:<lobby_id>`): lobby member joins/leaves, lobby updates, lobby chat
        - **Lobbies channel** (`lobbies`): global lobby list changes (created, updated, deleted)
        - **Group channel** (`group:<group_id>`): group member changes, group updates, group chat
        - **Groups channel** (`groups`): global group list changes
        - **Party channel** (`party:<party_id>`): party member changes, party updates, party chat

        ### **12.3 JS SDK Helper**
        The `GameRealtime` class (included in this SDK) wraps Phoenix.Socket with convenient channel helpers:
        ```javascript
        import { GameRealtime } from '@ughuuu/game_server'
        const realtime = new GameRealtime('https://your-server.com', accessToken)
        const userChannel = realtime.joinUserChannel(userId)
        userChannel.on('notification', payload => console.log(payload))
        ```
        Requires the `phoenix` npm package as a peer dependency: `npm install phoenix`

        ## **13. Real-time: WebRTC DataChannels**
        For low-latency game data, the server supports WebRTC DataChannels alongside WebSocket. The server acts as a WebRTC peer (not P2P between clients).

        ### **13.1 How It Works**
        1. Client connects via WebSocket and joins the **User channel**
        2. Client sends an SDP offer over the channel (`webrtc:offer` event)
        3. Server responds with an SDP answer (`webrtc:answer` event)
        4. ICE candidates are exchanged (`webrtc:ice` events)
        5. Once connected, named DataChannels carry game data at low latency

        ### **13.2 Default DataChannels**
        - **`events`** (reliable, ordered): important game events (player actions, state changes)
        - **`state`** (unreliable, unordered): high-frequency position/state sync

        ### **13.3 JS SDK Helper**
        The `GameWebRTC` class (included in this SDK, browser-only) handles signaling automatically:
        ```javascript
        import { GameRealtime, GameWebRTC } from '@ughuuu/game_server'
        const realtime = new GameRealtime('https://your-server.com', token)
        const userChannel = realtime.joinUserChannel(userId)
        const webrtc = new GameWebRTC(userChannel, {
          onData: (label, data) => console.log(label, data)
        })
        await webrtc.connect()
        webrtc.send('events', JSON.stringify({ type: 'move', x: 10, y: 20 }))
        ```
        """
      },
      paths: filter_api_paths(Paths.from_router(Router)),
      tags: [
        # --- Public API ---
        %Tag{
          name: "Authentication",
          description: "Login, registration, OAuth, and token management"
        },
        %Tag{name: "Users", description: "User profiles, metadata, and account management"},
        %Tag{name: "Friends", description: "Friend requests, blocking, and friend lists"},
        %Tag{name: "Lobbies", description: "Matchmaking rooms — create, join, leave, and manage"},
        %Tag{
          name: "Groups",
          description: "Persistent community groups with roles and permissions"
        },
        %Tag{
          name: "Parties",
          description: "Ephemeral party groups — invite-only, leader-managed"
        },
        %Tag{
          name: "Chat",
          description: "Real-time messaging across lobbies, groups, parties, and friends"
        },
        %Tag{name: "Notifications", description: "Persistent user notifications"},
        %Tag{name: "Leaderboards", description: "Ranked scoreboards and score submission"},
        %Tag{
          name: "Achievements",
          description: "Player achievements, progress tracking, and unlocks"
        },
        %Tag{name: "KV", description: "Per-user key-value storage"},
        %Tag{name: "Hooks", description: "Server scripting hooks"},
        %Tag{name: "Health", description: "Server health check"},
        # --- Admin API ---
        %Tag{name: "Admin – Users", description: "Admin user management"},
        %Tag{name: "Admin – Sessions", description: "Admin session management"},
        %Tag{name: "Admin – Lobbies", description: "Admin lobby management"},
        %Tag{name: "Admin – Groups", description: "Admin group management"},
        %Tag{name: "Admin – Chat", description: "Admin chat management"},
        %Tag{name: "Admin – Achievements", description: "Admin achievement management"},
        %Tag{name: "Admin – Notifications", description: "Admin notification management"},
        %Tag{name: "Admin – Leaderboards", description: "Admin leaderboard management"},
        %Tag{name: "Admin – KV", description: "Admin key-value storage management"}
      ],
      components: %Components{
        securitySchemes: %{
          "authorization" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            bearerFormat: "JWT",
            description:
              "JWT access token - obtain from /api/v1/login, /api/v1/auth/discord/callback, /api/v1/auth/google/callback, /api/v1/auth/facebook/callback, or /auth/apple"
          }
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end

  defp api_version do
    # Prefer an environment-supplied APP_VERSION when present (CI injects this),
    # then fall back to the application vsn or Mix project version.
    case System.get_env("APP_VERSION") || Application.spec(:game_server, :vsn) do
      nil -> Mix.Project.config()[:version] || "1.0.0"
      vsn -> to_string(vsn)
    end
  end

  # Filter out non-API routes (browser routes) from the OpenAPI spec
  defp filter_api_paths(paths) do
    Map.filter(paths, fn {path, _path_item} ->
      # Only include paths that start with /api/
      String.starts_with?(path, "/api/")
    end)
  end
end
