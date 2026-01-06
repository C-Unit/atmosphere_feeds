defmodule AtmosphereFeeds.Repo.Migrations.CreateAuthors do
  use Ecto.Migration

  def change do
    create table(:authors) do
      add :did, :string, null: false
      add :handle, :string
      add :display_name, :string
      add :avatar_url, :string

      timestamps()
    end

    create unique_index(:authors, [:did])
  end
end
