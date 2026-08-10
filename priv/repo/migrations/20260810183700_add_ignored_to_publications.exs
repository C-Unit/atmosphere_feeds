defmodule AtmosphereFeeds.Repo.Migrations.AddIgnoredToPublications do
  use Ecto.Migration

  def change do
    alter table(:publications) do
      add :ignored, :boolean, default: false, null: false
    end

    create index(:publications, [:ignored])
  end
end
