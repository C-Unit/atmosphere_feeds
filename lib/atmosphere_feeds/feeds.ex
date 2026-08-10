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

  def get_publication(id) do
    Publication
    |> preload(:author)
    |> Repo.get(id)
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

  @doc """
  Marks a publication as ignored (or un-ignores it).

  Ignored publications are dropped at ingestion: their records and the documents
  they publish are never persisted or broadcast.
  """
  def set_publication_ignored(%Publication{} = publication, ignored) when is_boolean(ignored) do
    publication
    |> Publication.ignore_changeset(ignored)
    |> Repo.update()
  end

  @doc """
  Returns true when the given `site` reference belongs to an ignored publication.

  A document's `site` field is either the publication's AT-URI or its plain URL,
  so both are checked.
  """
  def ignored_site?(nil), do: false

  def ignored_site?("at://" <> _ = at_uri) do
    Repo.exists?(from p in Publication, where: p.ignored and p.at_uri == ^at_uri)
  end

  def ignored_site?(url) when is_binary(url) do
    normalized = String.trim_trailing(url, "/")

    Repo.exists?(
      from p in Publication,
        where: p.ignored and fragment("rtrim(?, '/')", p.url) == ^normalized
    )
  end

  def ignored_site?(_), do: false

  def upsert_publication(attrs) do
    %Publication{}
    |> Publication.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace,
         [
           :url,
           :name,
           :description,
           :icon_cid,
           :theme_background,
           :theme_foreground,
           :theme_accent,
           :theme_accent_foreground,
           :show_in_discover,
           :author_id,
           :updated_at
         ]},
      conflict_target: :at_uri
    )
  end

  # Documents

  def list_recent_documents(limit \\ 50, opts \\ []) do
    publication_id = Keyword.get(opts, :publication_id)
    now = DateTime.utc_now()

    Document
    |> where([d], d.published_at <= ^now)
    |> maybe_filter_by_publication(publication_id)
    |> order_by([d], desc: d.published_at)
    |> limit(^limit)
    |> preload([:author, :publication])
    |> Repo.all()
  end

  # Without a filter, documents already stored for a since-ignored publication
  # stay out of the feed. Asking for that publication explicitly still shows
  # them, so an ignored publication can be reviewed and un-ignored.
  defp maybe_filter_by_publication(query, nil) do
    ignored_ids = from(p in Publication, where: p.ignored, select: p.id)
    where(query, [d], is_nil(d.publication_id) or d.publication_id not in subquery(ignored_ids))
  end

  defp maybe_filter_by_publication(query, id), do: where(query, [d], d.publication_id == ^id)

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
      on_conflict:
        {:replace,
         [
           :title,
           :path,
           :full_url,
           :description,
           :text_content,
           :tags,
           :cover_image_cid,
           :bsky_post_uri,
           :updated_at_source,
           :publication_id,
           :author_id,
           :updated_at
         ]},
      conflict_target: :at_uri
    )
  end
end
