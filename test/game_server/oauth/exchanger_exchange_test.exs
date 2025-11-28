defmodule GameServer.OAuth.ExchangerExchangeTest do
  use ExUnit.Case, async: false

  alias GameServer.OAuth.Exchanger

  # Define a small test client we can inject via application env. Placing this
  # at top-level ensures the module is compiled once and avoids repeated
  # "redefining module" warnings that happen when defmodule is evaluated in
  # setup blocks multiple times.
  defmodule TestClient do
    # Group all post/2 clauses together
    def post("https://discord.com/api/oauth2/token", opts) do
      case opts[:form] do
        %{code: "ok_code"} -> {:ok, %{status: 200, body: %{"access_token" => "d_token"}}}
        _ -> {:error, :bad_request}
      end
    end

    def post("https://oauth2.googleapis.com/token", opts) do
      case opts[:form] do
        %{code: "ok_code"} -> {:ok, %{status: 200, body: %{"access_token" => "g_token"}}}
        _ -> {:ok, %{status: 400, body: %{}}}
      end
    end

    def post("https://appleid.apple.com/auth/token", opts) do
      case opts[:form] do
        %{code: "ok_code"} ->
          payload = Jason.encode!(%{"sub" => "a1", "email" => "a@example.com"})
          b64 = Base.url_encode64(payload, padding: false)
          id_token = Enum.join(["h", b64, "s"], ".")

          {:ok, %{status: 200, body: %{"id_token" => id_token}}}

        _ ->
          {:ok, %{status: 400, body: %{}}}
      end
    end

    # Group all get/2 clauses together
    def get("https://discord.com/api/users/@me", opts) do
      case opts[:headers] do
        [{"Authorization", "Bearer d_token"}] ->
          {:ok, %{status: 200, body: %{"id" => "d1", "email" => "d@example.com"}}}

        _ ->
          {:error, :bad}
      end
    end

    def get("https://www.googleapis.com/oauth2/v2/userinfo", opts) do
      case opts[:headers] do
        [{"Authorization", "Bearer g_token"}] ->
          {:ok, %{status: 200, body: %{"id" => "g1", "email" => "g@example.com"}}}

        _ ->
          {:error, :bad}
      end
    end

    def get("https://graph.facebook.com/v18.0/oauth/access_token", opts) do
      case opts[:params] do
        %{code: "ok_code"} -> {:ok, %{status: 200, body: %{"access_token" => "f_token"}}}
        _ -> {:ok, %{status: 500, body: ""}}
      end
    end

    def get("https://graph.facebook.com/v18.0/me", opts) do
      case opts[:params] do
        %{access_token: "f_token"} ->
          {:ok, %{status: 200, body: %{"id" => "f1", "email" => "f@example.com"}}}

        _ ->
          {:error, :bad}
      end
    end
  end

  setup do
    Application.put_env(:game_server, :oauth_exchanger_client, TestClient)

    on_exit(fn -> Application.delete_env(:game_server, :oauth_exchanger_client) end)

    :ok
  end

  describe "exchange_discord_code/4" do
    test "returns user info on success" do
      assert {:ok, %{"email" => "d@example.com"}} =
               Exchanger.exchange_discord_code("ok_code", "cid", "sec", "r")
    end

    test "returns error on failure" do
      assert {:error, _} = Exchanger.exchange_discord_code("bad_code", "cid", "sec", "r")
    end
  end

  describe "exchange_google_code/4" do
    test "returns user info on success" do
      assert {:ok, %{"email" => "g@example.com"}} =
               Exchanger.exchange_google_code("ok_code", "cid", "sec", "r")
    end

    test "returns error on token exchange failure" do
      # the TestClient returns status 400 so the function should return error
      assert {:error, _} = Exchanger.exchange_google_code("bad", "cid", "sec", "r")
    end
  end

  describe "exchange_facebook_code/4" do
    test "returns user info on success" do
      assert {:ok, %{"email" => "f@example.com"}} =
               Exchanger.exchange_facebook_code("ok_code", "cid", "sec", "r")
    end

    test "returns error if user info parse fails" do
      # Provide a flow where exchange returns non-200
      assert {:error, _} = Exchanger.exchange_facebook_code("bad", "cid", "sec", "r")
    end
  end

  describe "exchange_apple_code/4" do
    test "parses id_token and returns user info on success" do
      assert {:ok, %{"email" => "a@example.com"}} =
               Exchanger.exchange_apple_code("ok_code", "cid", "secret", "r")
    end

    test "returns error when exchange fails" do
      assert {:error, _} = Exchanger.exchange_apple_code("bad", "cid", "secret", "r")
    end
  end
end
