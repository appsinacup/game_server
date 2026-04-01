defmodule GameServer.Achievements.Achievement do
  @moduledoc """
  Ecto schema for the `achievements` table.

  An achievement is a goal or milestone that players can unlock.

  ## Fields
  - `slug` — unique identifier (e.g., "first_lobby_join")
  - `title` — display name
  - `description` — human-readable description
  - `icon_url` — optional icon path/URL
  - `sort_order` — display ordering (lower = first)
  - `hidden` — if true, not shown until unlocked
  - `progress_target` — number of steps to complete (1 = one-shot, >1 = incremental)
  - `metadata` — arbitrary JSON data
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :title,
             :description,
             :icon_url,
             :sort_order,
             :hidden,
             :progress_target,
             :metadata,
             :inserted_at,
             :updated_at
           ]}

  schema "achievements" do
    field :slug, :string
    field :title, :string
    field :description, :string, default: ""
    field :icon_url, :string
    field :sort_order, :integer, default: 0
    field :hidden, :boolean, default: false
    field :progress_target, :integer, default: 1
    field :metadata, :map, default: %{}

    has_many :user_achievements, GameServer.Achievements.UserAchievement

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(slug title)a
  @optional_fields ~w(description icon_url sort_order hidden progress_target metadata)a

  @doc false
  def changeset(achievement, attrs) do
    achievement
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:progress_target, greater_than: 0)
    |> unique_constraint(:slug)
  end

  @doc """
  Returns the localized title for the given locale.

  Looks up `metadata["titles"][locale]`, falling back to `title`.

  ## Examples

      iex> a = %Achievement{title: "First Kill", metadata: %{"titles" => %{"es" => "Primera Baja"}}}
      iex> Achievement.localized_title(a, "es")
      "Primera Baja"
      iex> Achievement.localized_title(a, "en")
      "First Kill"
  """
  def localized_title(%{metadata: metadata, title: title}, locale) when is_binary(locale) do
    get_in(metadata || %{}, ["titles", locale]) || title
  end

  def localized_title(%{title: title}, _locale), do: title

  @doc """
  Returns the localized description for the given locale.

  Looks up `metadata["descriptions"][locale]`, falling back to `description`.
  """
  def localized_description(%{metadata: metadata, description: desc}, locale)
      when is_binary(locale) do
    get_in(metadata || %{}, ["descriptions", locale]) || desc
  end

  def localized_description(%{description: desc}, _locale), do: desc
end
