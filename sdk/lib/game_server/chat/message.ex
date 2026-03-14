defmodule GameServer.Chat.Message do
  @moduledoc """
  Chat message struct from GameServer.

  This is a stub module for SDK type definitions. The actual struct
  is provided by GameServer at runtime.

  ## Fields

  - `id` - Message ID (integer)
  - `content` - Message content (string)
  - `metadata` - Arbitrary message metadata (map)
  - `chat_type` - Chat type: `"lobby"`, `"group"`, or `"friend"` (string)
  - `chat_ref_id` - Reference ID (lobby_id, group_id, or sorted user pair) (integer)
  - `sender_id` - ID of the sender (integer)
  - `inserted_at` - Creation timestamp
  - `updated_at` - Last update timestamp
  """

  @type t :: %__MODULE__{
          id: integer(),
          content: String.t(),
          metadata: map(),
          chat_type: String.t(),
          chat_ref_id: integer(),
          sender_id: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :content,
    :metadata,
    :chat_type,
    :chat_ref_id,
    :sender_id,
    :inserted_at,
    :updated_at
  ]
end
