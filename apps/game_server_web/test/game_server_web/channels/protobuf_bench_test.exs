defmodule GameServerWeb.ProtobufBenchTest do
  @moduledoc """
  Compares the two realtime payload encodings on wire size and encode time.

  For every representative event fixture this encodes the same payload map
  through both production paths:

    * JSON — `Jason.encode_to_iodata!/1`, what the Phoenix V2 serializer
      runs for each `push/3`
    * protobuf — `GameServerWeb.EventCodec.encode/3`, what
      `GameServerWeb.ChannelPush.push_event/3` runs on `?format=protobuf`
      sockets

  Sizes are contractual (protobuf must stay smaller per event); timing is
  informational (printed table) with only a loose ratio bound so the test
  is not flaky on slow CI machines.

  Note: WebSocket JSON traffic is usually permessage-deflate compressed on
  the wire, so the size column overstates the real WS difference; it is the
  honest number for WebRTC DataChannels, which have no compression.

  Every fixture is a *full* payload. Realtime state events stopped sending
  partial maps when JSON delta encoding was removed, so a fixture with a
  handful of fields would measure a payload the server cannot produce.
  """

  use ExUnit.Case, async: true

  alias GameServerWeb.EventCodec

  @iterations 1_000

  test "protobuf encoding is smaller per event and comparable in encode time" do
    {:ok, ts, _} = DateTime.from_iso8601("2026-07-16T09:12:33Z")
    uuid = fn i -> "9f1c2d3e-4b5a-6c7d-8e9f-0a1b2c3d4e#{String.pad_leading("#{i}", 2, "0")}" end

    fixtures = [
      {"user:x", "updated",
       %{
         id: uuid.(1),
         email: "alice@example.com",
         profile_url: "",
         metadata: %{"rank" => 12},
         username: "alice",
         display_name: "Alice",
         lobby_id: "",
         party_id: "",
         is_online: true,
         last_seen_at: ts,
         linked_providers: %{
           google: false,
           facebook: false,
           discord: true,
           apple: false,
           steam: false,
           device: true
         },
         has_password: true
       }},
      {"user:x", "notification",
       %{
         id: uuid.(2),
         sender_id: uuid.(3),
         sender_name: "Alice",
         recipient_id: uuid.(4),
         title: "Friend request",
         content: "Alice sent you a friend request",
         metadata: %{"kind" => "friend_request"},
         inserted_at: ts
       }},
      {"user:x", "new_chat_message",
       %{
         id: uuid.(5),
         content: "gg wp everyone, rematch in 5?",
         metadata: %{},
         sender_id: uuid.(6),
         sender_name: "Alice",
         chat_type: "lobby",
         chat_ref_id: uuid.(7),
         inserted_at: ts
       }},
      {"user:x", "kv_updated",
       %{key: "loadout", user_id: uuid.(8), lobby_id: nil, data: %{"weapon" => 12}, metadata: %{}}},
      {"lobby:x", "updated",
       %{
         id: uuid.(9),
         title: "Ranked #4",
         host_id: uuid.(10),
         host_name: "Alice",
         hostless: false,
         max_users: 8,
         is_hidden: false,
         is_locked: true,
         metadata: %{"map" => "dust2"},
         is_passworded: false,
         slowdown: 0,
         spectator_count: 2
       }}
    ]

    rows =
      for {topic, event, payload} <- fixtures do
        json_encode = fn -> Jason.encode_to_iodata!(payload) end

        pb_encode = fn ->
          {:ok, iodata} = EventCodec.encode(topic, event, payload)
          iodata
        end

        json_bytes = IO.iodata_length(json_encode.())
        pb_bytes = IO.iodata_length(pb_encode.())

        {topic, event, json_bytes, pb_bytes, avg_us(json_encode), avg_us(pb_encode)}
      end

    header =
      String.pad_trailing("event", 26) <>
        String.pad_leading("json_B", 8) <>
        String.pad_leading("pb_B", 7) <>
        String.pad_leading("save", 7) <>
        String.pad_leading("json_us", 10) <>
        String.pad_leading("pb_us", 9)

    lines =
      for {topic, event, jb, pb, jt, pt} <- rows do
        String.pad_trailing("#{String.first(topic)}/#{event}", 26) <>
          String.pad_leading("#{jb}", 8) <>
          String.pad_leading("#{pb}", 7) <>
          String.pad_leading("#{round((1 - pb / jb) * 100)}%", 7) <>
          String.pad_leading("#{jt}", 10) <>
          String.pad_leading("#{pt}", 9)
      end

    IO.puts(Enum.join(["\n#{header}" | lines], "\n"))

    for {topic, event, json_bytes, pb_bytes, _jt, _pt} <- rows do
      assert pb_bytes < json_bytes,
             "protobuf (#{pb_bytes}B) not smaller than JSON (#{json_bytes}B) for #{topic} #{event}"
    end

    total_json_us = rows |> Enum.map(&elem(&1, 4)) |> Enum.sum()
    total_pb_us = rows |> Enum.map(&elem(&1, 5)) |> Enum.sum()

    # Loose regression guard only: encoding must stay the same order of
    # magnitude as JSON (both are microseconds per event in practice).
    assert total_pb_us < total_json_us * 10,
           "protobuf encode time (#{total_pb_us}us) regressed vs JSON (#{total_json_us}us)"
  end

  # Average microseconds per call over @iterations, after a small warmup.
  defp avg_us(fun) do
    Enum.each(1..50, fn _ -> fun.() end)
    {us, _} = :timer.tc(fn -> Enum.each(1..@iterations, fn _ -> fun.() end) end)
    Float.round(us / @iterations, 2)
  end
end
