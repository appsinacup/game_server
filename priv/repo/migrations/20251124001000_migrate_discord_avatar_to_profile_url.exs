defmodule GameServer.Repo.Migrations.MigrateDiscordAvatarToProfileUrl do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :profile_url, :string
    end

    # Populate new column from existing discord_avatar data if present
    execute("""
    UPDATE users
    SET profile_url = CASE
      WHEN discord_avatar IS NULL OR discord_avatar = '' THEN NULL
      WHEN discord_avatar LIKE 'http%' THEN discord_avatar
      WHEN discord_avatar LIKE 'a_%' THEN 'https://cdn.discordapp.com/avatars/' || discord_id || '/' || discord_avatar || '.gif'
      ELSE 'https://cdn.discordapp.com/avatars/' || discord_id || '/' || discord_avatar || '.png'
    END
    WHERE discord_avatar IS NOT NULL
    """)

    alter table(:users) do
      remove :discord_username
      remove :discord_avatar
    end
  end

  def down do
    alter table(:users) do
      add :discord_username, :string
      add :discord_avatar, :string
    end

    # Attempt to move profile_url back into discord_avatar when possible
    execute("""
    UPDATE users
    SET discord_avatar = CASE
        WHEN profile_url IS NULL THEN NULL
        WHEN profile_url LIKE 'https://cdn.discordapp.com/avatars/%' THEN
        -- remove prefix and strip file extension
          regexp_replace(profile_url, '^https://cdn.discordapp.com/avatars/[^/]+/([^\\.]+)(\\.(png|gif))?$', '\\1')
        ELSE profile_url
    END
    WHERE profile_url IS NOT NULL
    """)

    alter table(:users) do
      remove :profile_url
    end
  end
end
