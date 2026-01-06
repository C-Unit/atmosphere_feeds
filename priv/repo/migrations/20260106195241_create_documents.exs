defmodule AtmosphereFeeds.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :at_uri, :string, null: false
      add :did, :string, null: false
      add :rkey, :string, null: false
      add :title, :string, null: false
      add :path, :string
      add :full_url, :string
      add :description, :text
      add :text_content, :text
      add :tags, {:array, :string}, default: []
      add :cover_image_cid, :string
      add :bsky_post_uri, :string
      add :published_at, :utc_datetime, null: false
      add :updated_at_source, :utc_datetime
      add :publication_id, references(:publications, on_delete: :nilify_all)
      add :author_id, references(:authors, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:documents, [:at_uri])
    create index(:documents, [:did])
    create index(:documents, [:publication_id])
    create index(:documents, [:author_id])
    create index(:documents, [:published_at])
  end
end
