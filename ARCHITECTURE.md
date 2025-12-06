# Architecture

This document provides an overview of the GameServer (Gamend) architecture.

## 1. High-Level Overview

The system follows a typical Phoenix application structure with game clients (Godot/JavaScript SDKs) and web browsers connecting to the server. The Phoenix application exposes a REST API for game operations, a WebSocket layer for real-time updates, and a LiveView-based admin UI. All requests flow through authentication before reaching the domain logic, which interacts with external services like the database, OAuth providers, and monitoring.

```mermaid
flowchart TB
    subgraph Clients["Clients"]
        GameClients["Game Clients<br/>(Godot / JS SDK)"]
        Browser["Web Browser"]
    end

    subgraph Phoenix["Phoenix Application"]
        API["REST API"]
        WebUI["Web UI<br/>(LiveViews)"]
        Realtime["WebSocket<br/>Channels"]
        Domain["Domain Logic<br/>(Accounts, Lobbies,<br/>Friends, Leaderboards)"]
        Hooks["Server Scripting<br/>(Hooks)"]
        Auth["Authentication<br/>(JWT + Sessions)"]
    end

    subgraph External["External Services"]
        DB[(Database)]
        OAuth["OAuth Providers<br/>(Discord, Google,<br/>Apple, Facebook, Steam)"]
        Email["Email (SMTP)"]
        Monitoring["Monitoring<br/>(Sentry)"]
    end

    GameClients -->|"HTTP"| API
    GameClients -->|"WebSocket"| Realtime
    Browser -->|"HTTP"| API & WebUI

    API --> Auth
    API --> Domain
    WebUI --> Domain
    Realtime --> Domain

    Auth --> OAuth
    Domain --> Hooks
    Domain --> DB
    Domain --> Email
    Domain --> Monitoring
```

## 2. Authentication

The application supports multiple authentication methods, all returning JWT tokens for API access.

### 2.1 Email/Password & Device Token Authentication

For traditional email/password login or anonymous device-based authentication. The API uses JWT-based authentication with short-lived access tokens (15 min) and long-lived refresh tokens (30 days). Subsequent requests include the access token in the Authorization header. When access tokens expire, clients use the refresh token to obtain new credentials without re-authenticating.

```mermaid
sequenceDiagram
    participant Client
    participant API
    participant Guardian
    participant Accounts
    participant DB

    rect rgb(20, 23, 20)
        Note over Client,DB: Login Flow (Email/Password or Device Token)
        Client->>API: POST /api/v1/login<br/>or POST /api/v1/login/device
        API->>Accounts: get_user_by_email_and_password<br/>or find_or_create_device_user
        Accounts->>DB: Query/Create user
        DB-->>Accounts: User
        Accounts-->>API: User
        API->>Guardian: encode_and_sign(user)
        Guardian-->>API: {access_token, refresh_token}
        API-->>Client: {access_token, refresh_token}
    end

    rect rgb(20, 20, 23)
        Note over Client,DB: Authenticated Request
        Client->>API: GET /api/v1/me<br/>Authorization: Bearer {token}
        API->>Guardian: verify_token
        Guardian-->>API: User claims
        API->>Accounts: get_user
        Accounts->>DB: Query
        DB-->>Accounts: User
        Accounts-->>API: User
        API-->>Client: User data
    end

    rect rgb(23, 20, 20)
        Note over Client,DB: Token Refresh
        Client->>API: POST /api/v1/refresh<br/>{refresh_token}
        API->>Guardian: exchange(refresh_token)
        Guardian-->>API: {new_access_token, new_refresh_token}
        API-->>Client: {access_token, refresh_token}
    end
```

### 2.2 OAuth with Browser Redirect (Authorization Code Flow)

For OAuth authentication (Discord, Google, Apple, Facebook, Steam) when the game client cannot handle OAuth natively. The client requests an auth URL and session ID from the API, then opens the URL in a browser where the user authenticates with the provider. The browser redirects back to the server which stores the result. Meanwhile, the game client polls the session endpoint until completion, then receives its JWT tokens.

```mermaid
sequenceDiagram
    participant Client as Game Client
    participant API
    participant Browser
    participant Provider as OAuth Provider
    participant DB

    Client->>API: GET /api/v1/auth/{provider}
    API->>API: Create OAuth session
    API->>DB: Store session (pending)
    API-->>Client: {session_id, auth_url}
    
    Client->>Browser: Open auth_url
    Browser->>Provider: Redirect to OAuth
    Provider->>Browser: Login prompt
    Browser->>Provider: User authenticates
    Provider->>API: Callback with code
    API->>Provider: Exchange code for token
    Provider-->>API: User info
    API->>DB: Create/link user
    API->>DB: Update session (completed, with JWT)
    API-->>Browser: Redirect to success page
    
    loop Poll for completion
        Client->>API: GET /api/v1/auth/session/{id}
        API->>DB: Check session status
        alt Session completed
            API-->>Client: {status: completed, access_token, refresh_token}
        else Session pending
            API-->>Client: {status: pending}
        end
    end
```

### 2.3 OAuth with Direct Code Exchange

For clients that handle the OAuth flow themselves (e.g., native mobile apps using platform SDKs). The client obtains the authorization code from the provider using native SDKs, then POSTs it to the API callback endpoint to receive JWT tokens immediately—no browser or polling required.

```mermaid
sequenceDiagram
    participant Client as Game Client
    participant Provider as OAuth Provider
    participant API
    participant DB

    Client->>Provider: Initiate OAuth (native SDK)
    Provider->>Client: Login prompt
    Client->>Provider: User authenticates
    Provider-->>Client: Authorization code

    Client->>API: POST /api/v1/auth/{provider}/callback<br/>{code: "..."}
    API->>Provider: Exchange code for token
    Provider-->>API: User info
    API->>DB: Create/link user
    API->>API: Generate JWT tokens
    API-->>Client: {access_token, refresh_token, user}
```

This flow is simpler since there's no browser redirect or polling. It's ideal for:
- Native mobile apps using Google Sign-In, Apple Sign-In, or Facebook SDK
- Steam authentication using auth tickets

## 3. Real-time Updates (PubSub)

Real-time features use Phoenix PubSub for broadcasting events. Domain modules (Lobbies, Friends, Accounts) publish to topic-based channels. WebSocket channels and LiveViews subscribe to relevant topics to receive instant updates. This enables features like live lobby member lists or friend request notifications.

```mermaid
flowchart LR
    subgraph Publishers
        Lobbies["Lobbies Module"]
        Friends["Friends Module"]
        Accounts["Accounts Module"]
    end

    subgraph PubSub["Phoenix.PubSub"]
        LobbyTopic["lobby:{id}"]
        LobbiesTopic["lobbies"]
        UserTopic["user:{id}"]
    end

    subgraph Subscribers
        LobbyChannel["LobbyChannel"]
        LobbiesChannel["LobbiesChannel"]
        UserChannel["UserChannel"]
        LiveViews["LiveViews"]
    end

    Lobbies -->|broadcast| LobbyTopic & LobbiesTopic
    Friends -->|broadcast| UserTopic
    Accounts -->|broadcast| UserTopic

    LobbyTopic --> LobbyChannel
    LobbiesTopic --> LobbiesChannel & LiveViews
    UserTopic --> UserChannel
```

## 4. Hooks System

The hooks system provides server-side scripting capabilities. Elixir modules placed in the `modules/` directory are watched and compiled at runtime. These modules implement lifecycle callbacks (e.g., `after_user_register`, `before_lobby_create`) that are invoked automatically. Hooks can also expose custom RPC functions callable via the API, enabling game-specific server logic without modifying the core codebase.

## 5. Database Schema

The database schema supports the core features: users with authentication tokens, lobbies with membership tracking, friendships with request states, leaderboards with score records, and OAuth sessions for tracking authentication flows. Users can belong to one lobby at a time (via `lobby_id`), and all entities support JSON metadata for extensibility.

```mermaid
erDiagram
    users {
        id bigint PK
        email string UK
        display_name string
        hashed_password string
        metadata jsonb
        lobby_id bigint FK
        confirmed_at datetime
        inserted_at datetime
        updated_at datetime
    }

    users_tokens {
        id bigint PK
        user_id bigint FK
        token binary
        context string
        sent_to string
        inserted_at datetime
    }

    lobbies {
        id bigint PK
        name string UK
        title string
        host_id bigint FK
        hostless boolean
        max_users integer
        is_hidden boolean
        is_locked boolean
        password_hash string
        metadata jsonb
        inserted_at datetime
        updated_at datetime
    }

    friendships {
        id bigint PK
        sender_id bigint FK
        receiver_id bigint FK
        status string
        inserted_at datetime
        updated_at datetime
    }

    leaderboards {
        id bigint PK
        slug string
        title string
        description string
        sort_order string
        operator string
        starts_at datetime
        ends_at datetime
        metadata jsonb
        inserted_at datetime
        updated_at datetime
    }

    records {
        id bigint PK
        leaderboard_id bigint FK
        user_id bigint FK
        score float
        metadata jsonb
        inserted_at datetime
        updated_at datetime
    }

    oauth_sessions {
        id uuid PK
        status string
        provider string
        data jsonb
        expires_at datetime
        inserted_at datetime
        updated_at datetime
    }

    users ||--o{ users_tokens : "has"
    users ||--o| lobbies : "current lobby"
    users ||--o{ lobbies : "hosts"
    users ||--o{ friendships : "sender"
    users ||--o{ friendships : "receiver"
    users ||--o{ records : "has"
    leaderboards ||--o{ records : "contains"
```

## 6. Directory Structure

The codebase follows Phoenix conventions with a clear separation between domain logic (`lib/game_server/`) and web layer (`lib/game_server_web/`). Client SDKs are maintained in `clients/`, runtime hook scripts go in `modules/`, and the Elixir SDK stubs for IDE support live in `sdk/`.

```
game_server/
├── lib/
│   ├── game_server/           # Domain logic
│   │   ├── accounts/          # User management
│   │   ├── friends/           # Friend system
│   │   ├── hooks/             # Server scripting
│   │   ├── leaderboards/      # Leaderboard system
│   │   ├── lobbies/           # Lobby management
│   │   ├── oauth/             # OAuth helpers
│   │   ├── schedule/          # Cron-like scheduling
│   │   └── theme/             # UI theming
│   │
│   ├── game_server_web/       # Web layer
│   │   ├── auth/              # Guardian pipeline
│   │   ├── channels/          # WebSocket channels
│   │   ├── components/        # UI components
│   │   ├── controllers/       # HTTP controllers
│   │   │   └── api/v1/        # REST API v1
│   │   ├── live/              # LiveView modules
│   │   │   └── admin_live/    # Admin dashboard
│   │   ├── on_mount/          # LiveView hooks
│   │   └── plugs/             # Custom plugs
│   │
│   └── mix/                   # Mix tasks
│       └── tasks/             # Custom tasks (gen.sdk)
│
├── modules/                   # Runtime hooks (user scripts)
├── assets/                    # Frontend assets
├── clients/                   # Client SDKs
│   ├── godot/                 # Godot SDK
│   └── javascript/            # JavaScript SDK
├── sdk/                       # Elixir SDK stubs
├── config/                    # Configuration
├── priv/                      # Static assets & migrations
└── test/                      # Tests
```

## 7. Key Technologies

The stack is built on Elixir/Phoenix for high concurrency and fault tolerance. SQLite is used for simple deployments with PostgreSQL supported for production scale. Guardian handles JWT authentication while Ueberauth manages OAuth flows. Quantum provides cron-like job scheduling for recurring tasks.

| Component | Technology |
|-----------|------------|
| Framework | Phoenix 1.8 |
| Language | Elixir 1.19 |
| Database | SQLite3 / PostgreSQL |
| Real-time | Phoenix Channels, PubSub |
| Auth (JWT) | Guardian |
| Auth (OAuth) | Ueberauth |
| Scheduling | Quantum |
| CSS | Tailwind CSS 4 |
| Monitoring | Sentry, Telemetry |
