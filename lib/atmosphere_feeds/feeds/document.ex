defmodule AtmosphereFeeds.Feeds.Document do
  use Ecto.Schema
  import Ecto.Changeset

  schema "documents" do
    field :at_uri, :string
    field :did, :string
    field :rkey, :string
    field :title, :string
    field :path, :string
    field :full_url, :string
    field :description, :string
    field :text_content, :string
    field :tags, {:array, :string}, default: []
    field :cover_image_cid, :string
    field :bsky_post_uri, :string
    field :published_at, :utc_datetime
    field :updated_at_source, :utc_datetime

    belongs_to :publication, AtmosphereFeeds.Feeds.Publication
    belongs_to :author, AtmosphereFeeds.Feeds.Author

    timestamps()
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :at_uri,
      :did,
      :rkey,
      :title,
      :path,
      :full_url,
      :description,
      :text_content,
      :tags,
      :cover_image_cid,
      :bsky_post_uri,
      :published_at,
      :updated_at_source,
      :publication_id,
      :author_id
    ])
    |> validate_required([:at_uri, :did, :rkey, :title, :published_at])
    |> unique_constraint(:at_uri)
  end
end
