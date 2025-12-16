defmodule GameServerWeb.Api.V1.ProviderController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Accounts

  operation(:link_device,
    operation_id: "link_device",
    summary: "Link device ID",
    description: "Links a device_id to the current authenticated user's account.",
    tags: ["Authentication"],
    security: [%{"authorization" => []}],
    request_body:
      {"Device ID", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           device_id: %OpenApiSpex.Schema{type: :string}
         },
         required: [:device_id]
       }},
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      unauthorized: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def link_device(conn, %{"device_id" => device_id}) when is_binary(device_id) do
    user = conn.assigns.current_scope.user

    case Accounts.link_device_id(user, device_id) do
      {:ok, _user} ->
        json(conn, %{})

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to link device_id", details: errors})

      {:error, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to link device_id"})
    end
  end

  def link_device(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "device_id is required"})
  end

  operation(:unlink_device,
    operation_id: "unlink_device",
    summary: "Unlink device ID",
    description:
      "Unlinks the device_id from the current authenticated user. Requires at least one OAuth provider or password to remain.",
    tags: ["Authentication"],
    security: [%{"authorization" => []}],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      unauthorized: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def unlink_device(conn, _params) do
    user = conn.assigns.current_scope.user

    case Accounts.unlink_device_id(user) do
      {:ok, _user} ->
        json(conn, %{})

      {:error, :last_auth_method} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Cannot unlink device_id when it's your last authentication method"})

      {:error, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to unlink device_id"})
    end
  end

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
          enum: ["discord", "apple", "google", "facebook", "steam"]
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
        "steam" -> :steam
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
