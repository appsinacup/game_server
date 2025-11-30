defmodule GameServer.Accounts.UserNotifier do
  @moduledoc """
  Small helpers used to deliver transactional emails for the Accounts flow
  (confirmation, magic link, and email change instructions).

  These functions are thin wrappers over the configured application Mailer.
  """
  import Swoosh.Email

  alias GameServer.Accounts.User
  alias GameServer.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"GameServer", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Send a simple test email to the given recipient address. Used by admin tools
  to verify SMTP configuration and delivery.
  Returns the same shape as `deliver/3`.
  """
  def deliver_test_email(recipient) when is_binary(recipient) do
    subject = "GameServer — test message"

    body = """

    This is a test message sent from the GameServer admin test-email tool.

    If you received this message your email delivery configuration is working.

    """

    deliver(recipient, subject, body)
  end
end
