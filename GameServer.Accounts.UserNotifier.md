# `GameServer.Accounts.UserNotifier`

Small helpers used to deliver transactional emails for the Accounts flow
(confirmation, magic link, and email change instructions).

These functions are thin wrappers over the configured application Mailer.

# `deliver_confirmation_instructions`

# `deliver_login_instructions`

Deliver instructions to log in with a magic link.

# `deliver_test_email`

Send a simple test email to the given recipient address. Used by admin tools
to verify SMTP configuration and delivery.
Returns the same shape as `deliver/3`.

# `deliver_update_email_instructions`

Deliver instructions to update a user email.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
