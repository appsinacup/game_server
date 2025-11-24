![gamend banner](./priv/static/images/banner.png)

-----

<p align="center">Open source <b>game server</b> with <b>authentication, user management, and admin portal</b></p>

-----

<p align = "center">
    <strong>
        <a href="https://discord.com/invite/56dMud8HYn">Discord</a>
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
