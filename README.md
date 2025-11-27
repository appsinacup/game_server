![gamend banner](./priv/static/images/banner.png)

-----

**Open source _game server_ with _authentication, users, lobbies, and an admin portal_.**

Game + Backend = Gamend

-----

[Discord](https://discord.com/invite/56dMud8HYn)

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

## How to deploy

1. Fork this repo.
2. Go to fly.io and deploy (select the forked repo).
3. Set secrets all values in `.env.example`. Run locally `fly secrets sync` and `fly secrets deploy` (in case secrets don't deploy/update).
4. Configure all things from [Guides](https://gamend.appsinacup.com/docs/setup) page.
5. Monthly cost (without Postgres) will be about 5$.
