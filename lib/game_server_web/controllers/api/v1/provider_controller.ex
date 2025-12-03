defmodule GameServerWeb.Api.V1.ProviderController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Accounts

  operation(:unlink,
    operation_id: "unlink_provider",
    summary: "Unlink OAuth provider",
    description: "Unlinks a provider from the current authenticated user.",
    tags: ["Authentication"],
    security: [%{"authorization" => []}],
    parameters: [
      provider: [
        in: :path,
        name: "provider",
        schema: %OpenApiSpex.Schema{
          type: :string,
          enum: ["discord", "apple", "google", "facebook"]
        },
        required: true
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      unauthorized: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def unlink(conn, %{"provider" => provider}) do
    user = conn.assigns.current_scope.user

    provider_atom =
      case provider do
        "discord" -> :discord
        "apple" -> :apple
        "google" -> :google
        "facebook" -> :facebook
        _ -> :unknown_provider
      end

    if provider_atom == :unknown_provider do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Unknown provider"})
    else
      case Accounts.unlink_provider(user, provider_atom) do
        {:ok, _user} ->
          json(conn, %{})

        {:error, :last_provider} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Cannot unlink the last linked provider"})

        {:error, _} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Failed to unlink provider"})
      end
    end
  end
end
