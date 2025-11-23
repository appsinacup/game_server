# GameServer

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Production Deployment

### Fly.io Setup

1. **Install Fly CLI** and authenticate:
   ```bash
   curl -L https://fly.io/install.sh | sh
   fly auth login
   ```

2. **Deploy to Fly.io**:
   ```bash
   fly deploy
   ```

3. **Set production secrets**:
   ```bash
   fly secrets set SECRET_KEY_BASE="$(mix phx.gen.secret)"
   ```

### Email Configuration

**Fly.io recommends Resend** for transactional emails (3,000 free emails/month):

1. **Sign up for Resend**: https://resend.com
2. **Get your API key** from the Resend dashboard
3. **Set Fly.io secrets**:
   ```bash
   fly secrets set SMTP_USERNAME="resend"
   fly secrets set SMTP_PASSWORD="your_resend_api_key"
   ```

**Alternative providers:**
- **Mailgun**: `SMTP_RELAY="smtp.mailgun.org"` (Phoenix standard)
- **SendGrid**: `SMTP_RELAY="smtp.sendgrid.net"`
- **Gmail**: `SMTP_RELAY="smtp.gmail.com"` (requires App Password)

**Auto-activation:** If no email provider is configured (`SMTP_PASSWORD` not set), new user accounts are automatically activated without requiring email confirmation. This is perfect for development or when you don't want to set up email immediately.

4. **Test email delivery** by registering a user or triggering password reset

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
