![gamend banner](./priv/static/images/banner.png)

-----

<p align="center">Open source <b>game server</b> with <b>authentication, user management, and admin portal</b></p>

-----

<p align = "center">
    <strong>
        <a href="https://github.com/appsinacup/game_server/blob/main/CHANGELOG.md">Changelog</a> | <a href="https://discord.gg/7BQDHesck8">Discord</a>
    </strong>
</p>

To start your server:

* Run `mix setup` to install and setup dependencies.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Authentication

This application supports two authentication methods:

### Browser Authentication (Session-based)

Traditional session-based authentication for browser flows:
- Email/password registration and login
- Discord OAuth login  
- Session tokens stored in database
- Managed via cookies and Phoenix sessions

### API Authentication (JWT)

Modern JWT authentication using access + refresh tokens (industry standard):

**Token Types:**
- **Access tokens**: Short-lived (15 minutes), used for API requests
- **Refresh tokens**: Long-lived (30 days), used to obtain new access tokens

**Available Endpoints:**
- `POST /api/v1/login` - Login with email/password, returns both tokens
- `POST /api/v1/refresh` - Exchange refresh token for new access token
- `DELETE /api/v1/logout` - Logout (client discards tokens)
- `GET /api/v1/auth/discord` - Get Discord OAuth URL
- `GET /api/v1/auth/discord/callback` - Discord OAuth callback, returns tokens

**Protected Routes (require access token):**
- `GET /api/v1/me` - Get current user info
- `GET /api/v1/me/metadata` - Get user metadata

#### API Authentication Flow

1. **Login with email/password:**
   ```bash
   curl -X POST http://localhost:4000/api/v1/login \
     -H "Content-Type: application/json" \
     -d '{"email": "user@example.com", "password": "password"}'
   ```

   Response:
   ```json
   {
     "data": {
       "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
       "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
       "token_type": "Bearer",
       "expires_in": 900,
       "user": {"id": 1, "email": "user@example.com"}
     }
   }
   ```

2. **Use access token for API requests:**
   ```bash
   curl http://localhost:4000/api/v1/me \
     -H "Authorization: Bearer <access_token>"
   ```

3. **Refresh when access token expires:**
   ```bash
   curl -X POST http://localhost:4000/api/v1/refresh \
     -H "Content-Type: application/json" \
     -d '{"refresh_token": "<refresh_token>"}'
   ```

   Returns a new access token (refresh token stays valid).

#### Discord OAuth for API

Discord OAuth works the same way - exchange the OAuth code for **your app's JWT tokens**:
1. Redirect user to Discord OAuth URL from `GET /api/v1/auth/discord`
2. Discord redirects back to `/api/v1/auth/discord/callback?code=...`
3. Backend exchanges Discord code for user info
4. Backend returns **access_token** and **refresh_token** (not Discord's token)
5. Client uses your tokens for all subsequent requests

Discord's OAuth token is only used once during login and discarded. Your app issues its own JWT tokens.

#### Configuration

For production, set the `GUARDIAN_SECRET_KEY` environment variable (or it will use `SECRET_KEY_BASE` by default):

```bash
export GUARDIAN_SECRET_KEY=$(mix phx.gen.secret)
```

See the API documentation at `/api/docs` for all available endpoints.

## Hooks / Callbacks

You can extend core lifecycle events (user registration, login, provider linking, deletion)
by implementing the `GameServer.Hooks` behaviour and configuring it in your app config.

Example (Elixir module):

  # config/runtime.exs or config.exs
  config :game_server, :hooks_module, MyApp.HooksImpl

The behaviour includes callbacks like `before_user_register/1`, `after_user_register/1`,
`before_user_login/1`, `after_user_login/1`, `before_account_link/3`, `after_account_link/1`,
`before_user_delete/1` and `after_user_delete/1`.

There's also a tiny Lua invoker (`GameServer.Hooks.LuaInvoker`) in case you want to delegate
hook logic to an external Lua script. Configure the script path with `:hooks_lua_script`; a
small example script is provided at `priv/hooks/example.lua`.


