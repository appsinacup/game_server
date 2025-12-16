defmodule GameServerWeb.Auth.Guardian do
  @moduledoc """
  Guardian implementation for JWT-based authentication.

  This module handles encoding and decoding JWT tokens for API authentication.
  It works alongside the existing session-based authentication for browser flows.
  """

  use Guardian, otp_app: :game_server

  alias GameServer.Accounts

  @doc """
  Encodes the user ID into the JWT token as the subject.
  """
  def subject_for_token(%{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def subject_for_token(_, _) do
    {:error, :no_id_provided}
  end

  @doc """
  Retrieves the user from the database using the subject (user ID) from the token.
  """
  def resource_from_claims(%{"sub" => id}) do
    case Integer.parse(id) do
      {user_id, ""} ->
        case Accounts.get_user(user_id) do
          %{} = user -> {:ok, user}
          nil -> {:error, :user_not_found}
        end

      _ ->
        {:error, :invalid_id}
    end
  end

  def resource_from_claims(_claims) do
    {:error, :no_subject}
  end
end
