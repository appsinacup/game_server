# Gamend = Game + Backend

I am working on a new open source game server with authentication, users, lobbies, server scripting and admin portal, built with Elixir.

- [Github](https://github.com/appsinacup/game_server)
- [Guides](https://gamend.appsinacup.com/docs/setup)


# Competition

This is how it compares with what exists today:

|Solution|Language|Auth|Persistence|Friends|Scaling|Cost after ~5k CCU|
|-|-|-|-|-|-|-|
|**Gamend**|Elixir|Yes|SQLite / PostgreSQL|Yes|Horizontal (BEAM clustering)|$0|
|**Nakama**|Go|Yes|PostgreSQL|Yes|Manual sharding or paid cloud|$1k+/mo (cloud)|
|**Colyseus**|TypeScript|Beta|No|No|Node clustering|$0|

- Note 1: Since **Gamend** works with SQLite also, hosting a single instance costs just 5$.
- Note 2: **Nakama** costs after scaling because it either requires manual configuration (hard to setup, not trivial) or enterprise version. **Colyseus** and **Gamend** both scale normally, without any enterprise edition. [reddit/nakama_not_an_opensource_distributed_server](https://www.reddit.com/r/gamedev/comments/7wzmwd/nakama_not_an_opensource_distributed_server_for/)

# Features

a. **Authentication**:

- Email + password
- Magic links
- OAuth 2.0 / OIDC providers (Steam, Google, Discord, Facebook, Apple)
- JWT and session support
- Password reset, email verification

![](gamend/auth.png)

b. **Realtime lobby system via Phoenix Channels and Presence**:

- Create/join public or private lobbies
- Live player list with metadata, as well as live lobby data.
- In-game ready checks and scripting

![](gamend/lobbies.png)

c. **User profiles and persistent data**:

- PostgreSQL or SQLite (for lightweight setups)

![](gamend/settings.png)

d. **Responsive web UI included**

- Login, registration, lobby browser, profile pages

![](gamend/home.png)

e. **Guides**

- Guides on how to configure everything on server side (eg. oauth, etc.) and on the client side.

![](gamend/guides.png)

f. **Admin dashboard**

- User management, lobby overview, basic analytics
- Integrated Sentry error tracking

![](gamend/config.png)

# Roadmap

I intend to add to it also:
- Leaderboards
- Groups
- Tournaments
- etc.
