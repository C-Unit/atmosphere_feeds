defmodule AtmosphereFeeds.Feeds.Publication do
  use Ecto.Schema
  import Ecto.Changeset

  schema "publications" do
    field :at_uri, :string
    field :did, :string
    field :rkey, :string
    field :url, :string
    field :name, :string
    field :description, :string
    field :icon_cid, :string
    field :theme_background, :string
    field :theme_foreground, :string
    field :theme_accent, :string
    field :theme_accent_foreground, :string
    field :show_in_discover, :boolean, default: true

    belongs_to :author, AtmosphereFeeds.Feeds.Author
    has_many :documents, AtmosphereFeeds.Feeds.Document

    timestamps()
  end

  def changeset(publication, attrs) do
    publication
    |> cast(attrs, [
      :at_uri,
      :did,
      :rkey,
      :url,
      :name,
      :description,
      :icon_cid,
      :theme_background,
      :theme_foreground,
      :theme_accent,
      :theme_accent_foreground,
      :show_in_discover,
      :author_id
    ])
    |> validate_required([:at_uri, :did, :rkey, :url, :name])
    |> unique_constraint(:at_uri)
  end
end
