defmodule GameServer.OAuth.ExchangerTest do
  use ExUnit.Case, async: true

  alias GameServer.OAuth.Exchanger

  describe "parse_apple_id_token/1" do
    test "parses a valid base64-url encoded payload" do
      payload = Jason.encode!(%{"sub" => "user1", "email" => "u@example.com"})
      b64 = payload |> Base.url_encode64(padding: false)
      token = ["hdr", b64, "sig"] |> Enum.join(".")

      assert {:ok, %{"sub" => "user1", "email" => "u@example.com"}} =
               Exchanger.parse_apple_id_token(token)
    end

    test "returns error for malformed token" do
      assert {:error, _} = Exchanger.parse_apple_id_token("not-a.jwt")
    end
  end
end
