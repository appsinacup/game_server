defmodule GameServer.Accounts.UsernameGenerator do
  @moduledoc """
  Generates default usernames for new users.

  OAuth signups get a slug of the provider display name ("Dragoș" →
  `dragos-4821`); email and device signups get a random word from the
  embedded list below (`sheep-4821`) — never anything derived from the
  email address, which would let strangers guess it. The numeric suffix is
  random, not a sequential discriminator, so there is no counter to
  exhaust; callers retry with a higher `attempt` on collision, which widens
  the suffix.
  """

  # Curated list for generated handles: lowercase a-z only, short, neutral.
  @words ~w(
    acorn alder alpaca amber antler apricot aspen aster auburn aurora
    badger bamboo barley basil bass beacon beaver beech birch bison
    bluebell boulder bramble breeze brook bumble burrow cactus canyon caper
    cardinal cascade cedar cherry chestnut chipmunk cider cinder citrus clover
    cobalt comet compass condor copper coral cosmos cougar cricket crystal
    cypress dahlia dapple deer delta dew dingo dolphin drake drift
    dune eagle ebony echo eland elk elm ember ermine falcon
    fawn fennel fern finch fjord flint fog forest fox foxglove
    gale garnet gecko geyser ginger glacier glade goose granite grove
    gull harbor hare hawk hazel heather hedgehog heron hickory holly
    ibis iris ivory jackal jade jasper juniper kestrel kiwi koala
    lagoon lark laurel lemur lichen lilac linden lotus lynx magpie
    mallow maple marigold marlin marmot meadow mesa mink minnow mistral
    moss moth myrtle nectar newt nimbus nutmeg oak ocelot olive
    onyx opal orchid oriole osprey otter owl panda pebble pecan
    pelican peony pepper petrel pine pistachio plover plum pond poppy
    prairie puffin quail quartz quince raccoon raven reed ridge river
    robin rowan saffron sage salmon sandpiper sapling seal sedge sequoia
    shale sheep shore sierra sparrow spruce squirrel starling stoat stone
    stork summit sunflower swallow swift sycamore tapir teal tern thicket
    thistle thrush tide topaz toucan trout tulip tundra turtle vale
    verbena violet vole walnut warbler willow winter wolf wren zephyr
  )

  @suffix_digits 4
  @wide_suffix_digits 6

  @doc """
  Generate a username candidate from registration attrs (string keys).

  Uses `attrs["display_name"]` when it slugs to something usable, a random
  word otherwise. Attempts beyond 3 widen the numeric suffix.
  """
  @spec generate(map(), pos_integer()) :: String.t()
  def generate(attrs \\ %{}, attempt \\ 1) do
    base = slug(attrs["display_name"]) || Enum.random(@words)
    digits = if attempt > 3, do: @wide_suffix_digits, else: @suffix_digits
    max_base = GameServer.Limits.get(:max_username) - digits - 1

    base
    |> String.slice(0, max_base)
    |> String.replace(~r/[._-]+$/, "")
    |> Kernel.<>("-" <> suffix(digits))
  end

  @doc """
  Best-effort ASCII slug of a display name in username format; `nil` when
  too little survives transliteration.
  """
  @spec slug(term()) :: String.t() | nil
  def slug(name) when is_binary(name) do
    slug =
      name
      |> String.normalize(:nfkd)
      |> String.replace(~r/[^\x00-\x7F]/, "")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9._-]+/, "-")
      |> String.replace(~r/[._-]{2,}/, "-")
      |> String.replace(~r/^[._-]+|[._-]+$/, "")

    if String.length(slug) >= GameServer.Limits.get(:min_username), do: slug, else: nil
  end

  def slug(_), do: nil

  defp suffix(digits) do
    limit = Integer.pow(10, digits)

    (:rand.uniform(limit) - 1)
    |> Integer.to_string()
    |> String.pad_leading(digits, "0")
  end
end
