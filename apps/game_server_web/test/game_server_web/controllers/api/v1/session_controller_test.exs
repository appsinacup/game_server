defmodule GameServerWeb.Api.V1.SessionControllerTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Accounts.User
  alias GameServer.Repo

  @valid_email "testuser@example.com"
  @valid_password "hello world!"

  setup do
    # Create a user with email and hashed password directly
    # This mimics what would happen after email/password registration
    hashed_password = Bcrypt.hash_pwd_salt(@valid_password)

    user = %User{
      email: @valid_email,
      hashed_password: hashed_password,
      confirmed_at: DateTime.utc_now(:second)
    }

    {:ok, user} = Repo.insert(user)
    %{user: user}
  end

  describe "POST /api/v1/login" do
    test "returns access and refresh tokens on successful login", %{conn: conn, user: user} do
      conn =
        post(conn, "/api/v1/login", %{
          email: @valid_email,
          password: @valid_password
        })

      resp = json_response(conn, 200)

      assert %{
               "data" => %{
                 "access_token" => access_token,
                 "refresh_token" => refresh_token,
                 "expires_in" => 900,
                 "user_id" => user_id
               }
             } = resp

      assert user_id == user.id

      assert is_binary(access_token)
      assert is_binary(refresh_token)
      assert access_token != refresh_token
    end

    test "returns 401 with invalid credentials", %{conn: conn} do
      conn =
        post(conn, "/api/v1/login", %{
          email: "wrong@example.com",
          password: "wrongpassword"
        })

      assert %{"error" => _} = json_response(conn, 401)
    end

    test "device login creates and returns tokens", %{conn: conn} do
      device_id = "device:#{System.unique_integer([:positive])}"

      conn = post(conn, "/api/v1/login/device", %{device_id: device_id})

      resp = json_response(conn, 200)

      assert %{
               "data" => %{
                 "access_token" => access_token,
                 "refresh_token" => refresh_token,
                 "expires_in" => 900,
                 "user_id" => device_user_id
               }
             } = resp

      assert is_integer(device_user_id) and device_user_id > 0

      assert is_binary(access_token)
      assert is_binary(refresh_token)

      # ensure user record was created and has device_id set
      assert %GameServer.Accounts.User{device_id: ^device_id} =
               GameServer.Repo.get_by(GameServer.Accounts.User, device_id: device_id)
    end

    test "device login returns existing user tokens", %{conn: conn} do
      # Create a user pre-attached to device_id
      device_id = "device_pre_#{System.unique_integer([:positive])}"

      {:ok, user} =
        GameServer.Accounts.register_user(%{
          email: "devuser#{System.unique_integer([:positive])}@example.com",
          password: "longenoughpass",
          device_id: device_id
        })

      assert user.device_id == device_id

      conn = post(conn, "/api/v1/login/device", %{device_id: device_id})

      resp = json_response(conn, 200)
      assert %{"data" => %{"access_token" => access_token, "user_id" => returned_id}} = resp
      assert returned_id == user.id

      assert is_binary(access_token)
    end
  end

  describe "POST /api/v1/refresh" do
    test "returns new access token with valid refresh token", %{conn: conn, user: user} do
      # Login to get tokens
      conn =
        post(conn, "/api/v1/login", %{
          email: @valid_email,
          password: @valid_password
        })

      %{"data" => %{"refresh_token" => refresh_token}} = json_response(conn, 200)

      # Use refresh token to get new access token
      conn = build_conn()
      conn = post(conn, "/api/v1/refresh", %{refresh_token: refresh_token})

      resp = json_response(conn, 200)

      assert %{
               "data" => %{
                 "access_token" => new_access_token,
                 "refresh_token" => returned_refresh_token,
                 "user_id" => user_id,
                 "expires_in" => 900
               }
             } = resp

      assert is_binary(new_access_token)
      assert returned_refresh_token == refresh_token
      assert user_id == user.id
    end

    test "returns 401 with invalid refresh token", %{conn: conn} do
      conn = post(conn, "/api/v1/refresh", %{refresh_token: "invalid.token.here"})

      assert %{"error" => _} = json_response(conn, 401)
    end

    test "returns 401 when using access token instead of refresh token", %{conn: conn} do
      # Login to get tokens
      conn =
        post(conn, "/api/v1/login", %{
          email: @valid_email,
          password: @valid_password
        })

      %{"data" => %{"access_token" => access_token}} = json_response(conn, 200)

      # Try to use access token for refresh (should fail)
      conn = build_conn()
      conn = post(conn, "/api/v1/refresh", %{refresh_token: access_token})

      assert %{"error" => _} = json_response(conn, 401)
    end

    test "returns 400 when refresh_token is missing", %{conn: conn} do
      conn = post(conn, "/api/v1/refresh", %{})

      assert %{"error" => "refresh_token is required"} = json_response(conn, 400)
    end
  end

  describe "DELETE /api/v1/logout" do
    test "returns 200 with empty object", %{conn: conn} do
      conn = delete(conn, "/api/v1/logout")

      assert json_response(conn, 200) == %{}
    end
  end
end
