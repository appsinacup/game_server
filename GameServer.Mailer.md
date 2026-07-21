# `GameServer.Mailer`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/mailer.ex#L1)

# `deliver`

```elixir
@spec deliver(Swoosh.Email.t(), Keyword.t()) :: {:ok, term()} | {:error, term()}
```

Delivers an email.

If the email is delivered it returns an `{:ok, result}` tuple. If it fails,
returns an `{:error, error}` tuple.

# `deliver!`

```elixir
@spec deliver!(Swoosh.Email.t(), Keyword.t()) :: term() | no_return()
```

Delivers an email, raises on error.

If the email is delivered, it returns the result. If it fails, it raises
a `DeliveryError`.

# `deliver_many`

```elixir
@spec deliver_many(
  [
    %Swoosh.Email{
      assigns: term(),
      attachments: term(),
      bcc: term(),
      cc: term(),
      from: term(),
      headers: term(),
      html_body: term(),
      private: term(),
      provider_options: term(),
      reply_to: term(),
      subject: term(),
      text_body: term(),
      to: term()
    }
  ],
  Keyword.t()
) :: {:ok, term()} | {:error, term()}
```

Delivers a list of emails.

It accepts a list of `%Swoosh.Email{}` as its first parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
