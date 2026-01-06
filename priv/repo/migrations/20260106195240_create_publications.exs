defmodule AtmosphereFeeds.Repo.Migrations.CreatePublications do
  use Ecto.Migration

  def change do
    create table(:publications) do
      add :at_uri, :string, null: false
      add :did, :string, null: false
      add :rkey, :string, null: false
      add :url, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :icon_cid, :string
      add :theme_background, :string
      add :theme_foreground, :string
      add :theme_accent, :string
      add :theme_accent_foreground, :string
      add :show_in_discover, :boolean, default: true
      add :author_id, references(:authors, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:publications, [:at_uri])
    create index(:publications, [:did])
    create index(:publications, [:author_id])
  end
end
