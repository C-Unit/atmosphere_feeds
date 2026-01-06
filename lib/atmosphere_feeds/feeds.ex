defmodule AtmosphereFeeds.Feeds do
  @moduledoc """
  Context for managing publications and documents from the atmosphere.
  """

  import Ecto.Query
  alias AtmosphereFeeds.Repo
  alias AtmosphereFeeds.Feeds.{Author, Publication, Document}

  @pubsub AtmosphereFeeds.PubSub
  @topic "feeds"

  # PubSub

  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  def broadcast_new_document(document) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:new_document, document})
  end

  def broadcast_new_publication(publication) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:new_publication, publication})
  end

  # Authors

  def get_author_by_did(did) do
    Repo.get_by(Author, did: did)
  end

  def create_author(attrs) do
    %Author{}
    |> Author.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_author(attrs) do
    %Author{}
    |> Author.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:handle, :display_name, :avatar_url, :updated_at]},
      conflict_target: :did
    )
  end

  # Publications

  def list_recent_publications(limit \\ 50) do
    Publication
    |> order_by([p], desc: p.inserted_at)
    |> limit(^limit)
    |> preload(:author)
    |> Repo.all()
  end

  def get_publication!(id) do
    Publication
    |> preload(:author)
    |> Repo.get!(id)
  end

  def get_publication_by_at_uri(at_uri) do
    Repo.get_by(Publication, at_uri: at_uri)
  end

  def create_publication(attrs) do
    %Publication{}
    |> Publication.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_publication(attrs) do
    %Publication{}
    |> Publication.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:url, :name, :description, :icon_cid, :theme_background,
        :theme_foreground, :theme_accent, :theme_accent_foreground, :show_in_discover,
        :author_id, :updated_at]},
      conflict_target: :at_uri
    )
  end

  # Documents

  def list_recent_documents(limit \\ 50) do
    Document
    |> order_by([d], desc: d.published_at)
    |> limit(^limit)
    |> preload([:author, :publication])
    |> Repo.all()
  end

  def get_document!(id) do
    Document
    |> preload([:author, :publication])
    |> Repo.get!(id)
  end

  def get_document_by_at_uri(at_uri) do
    Repo.get_by(Document, at_uri: at_uri)
  end

  def create_document(attrs) do
    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
  end

  def upsert_document(attrs) do
    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:title, :path, :full_url, :description, :text_content,
        :tags, :cover_image_cid, :bsky_post_uri, :updated_at_source, :publication_id,
        :author_id, :updated_at]},
      conflict_target: :at_uri
    )
  end
end
