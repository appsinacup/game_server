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
    test "returns access and refresh tokens on successful login", %{conn: conn} do
      conn =
        post(conn, "/api/v1/login", %{
          email: @valid_email,
          password: @valid_password
        })

      assert %{
               "data" => %{
                 "access_token" => access_token,
                 "refresh_token" => refresh_token,
                 "expires_in" => 900
               }
             } = json_response(conn, 200)

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
  end

  describe "POST /api/v1/refresh" do
    test "returns new access token with valid refresh token", %{conn: conn} do
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

      assert %{
               "access_token" => new_access_token,
               "expires_in" => 900
             } = json_response(conn, 200)

      assert is_binary(new_access_token)
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
    test "returns 204 No Content", %{conn: conn} do
      conn = delete(conn, "/api/v1/logout")

      assert response(conn, 204) == ""
    end
  end
end
