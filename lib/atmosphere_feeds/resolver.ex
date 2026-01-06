defmodule AtmosphereFeeds.Resolver do
  @moduledoc """
  Resolves AT Protocol references (DIDs, AT URIs) and stores resolved data.
  """

  require Logger
  alias AtmosphereFeeds.Feeds
  alias AtmosphereFeeds.Repo

  @doc """
  Resolves and stores a publication record from firehose data.
  """
  def resolve_and_store_publication(did, rkey, record) do
    at_uri = "at://#{did}/site.standard.publication/#{rkey}"

    with {:ok, author} <- resolve_author(did) do
      attrs = %{
        at_uri: at_uri,
        did: did,
        rkey: rkey,
        url: record["url"],
        name: record["name"],
        description: record["description"],
        icon_cid: get_blob_cid(record["icon"]),
        theme_background: extract_theme_color(record, "background"),
        theme_foreground: extract_theme_color(record, "foreground"),
        theme_accent: extract_theme_color(record, "accent"),
        theme_accent_foreground: extract_theme_color(record, "accentForeground"),
        show_in_discover: get_in(record, ["preferences", "showInDiscover"]) != false,
        author_id: author.id
      }

      case Feeds.upsert_publication(attrs) do
        {:ok, publication} ->
          publication = Repo.preload(publication, :author)
          Feeds.broadcast_new_publication(publication)
          {:ok, publication}

        {:error, changeset} ->
          Logger.warning("Failed to store publication #{at_uri}: #{inspect(changeset.errors)}")
          {:error, changeset}
      end
    end
  end

  @doc """
  Resolves and stores a document record from firehose data.
  """
  def resolve_and_store_document(did, rkey, record) do
    at_uri = "at://#{did}/site.standard.document/#{rkey}"

    with {:ok, author} <- resolve_author(did),
         {:ok, publication, site_url} <- resolve_site(record["site"]) do
      full_url = build_full_url(site_url, record["path"])

      attrs = %{
        at_uri: at_uri,
        did: did,
        rkey: rkey,
        title: record["title"],
        path: record["path"],
        full_url: full_url,
        description: record["description"],
        text_content: record["textContent"],
        tags: record["tags"] || [],
        cover_image_cid: get_blob_cid(record["coverImage"]),
        bsky_post_uri: get_bsky_post_uri(record["bskyPostRef"]),
        published_at: parse_datetime(record["publishedAt"]),
        updated_at_source: parse_datetime(record["updatedAt"]),
        publication_id: publication && publication.id,
        author_id: author.id
      }

      case Feeds.upsert_document(attrs) do
        {:ok, document} ->
          document = Repo.preload(document, [:author, :publication])
          Feeds.broadcast_new_document(document)
          {:ok, document}

        {:error, changeset} ->
          Logger.warning("Failed to store document #{at_uri}: #{inspect(changeset.errors)}")
          {:error, changeset}
      end
    end
  end

  @doc """
  Resolves a DID to an author, fetching profile if not cached.
  """
  def resolve_author(did) do
    case Feeds.get_author_by_did(did) do
      nil -> fetch_and_create_author(did)
      author -> {:ok, author}
    end
  end

  defp fetch_and_create_author(did) do
    case Exosphere.ATProto.Bsky.get_profile(did) do
      {:ok, profile} ->
        attrs = %{
          did: did,
          handle: profile["handle"],
          display_name: profile["displayName"],
          avatar_url: profile["avatar"]
        }

        Feeds.upsert_author(attrs)

      {:error, reason} ->
        Logger.warning("Failed to fetch profile for #{did}: #{inspect(reason)}")
        Feeds.upsert_author(%{did: did})
    end
  end

  @doc """
  Resolves the site field, which can be either an AT URI or a plain URL.
  Returns {:ok, publication | nil, site_url | nil}
  """
  def resolve_site(nil), do: {:ok, nil, nil}

  def resolve_site("at://" <> _ = at_uri) do
    case Feeds.get_publication_by_at_uri(at_uri) do
      nil ->
        case fetch_and_create_publication(at_uri) do
          {:ok, publication} -> {:ok, publication, publication && publication.url}
          {:error, _} -> {:ok, nil, nil}
        end

      publication ->
        {:ok, publication, publication.url}
    end
  end

  def resolve_site(url) when is_binary(url) do
    {:ok, nil, url}
  end

  @doc """
  Resolves a publication AT URI, fetching if not cached.
  """
  def resolve_publication(nil), do: {:ok, nil}

  def resolve_publication(at_uri) do
    case Feeds.get_publication_by_at_uri(at_uri) do
      nil -> fetch_and_create_publication(at_uri)
      publication -> {:ok, publication}
    end
  end

  defp fetch_and_create_publication(at_uri) do
    with {:ok, did, _collection, rkey} <- parse_at_uri(at_uri),
         {:ok, record} <- fetch_record(did, "site.standard.publication", rkey) do
      resolve_and_store_publication(did, rkey, record)
    else
      {:error, reason} ->
        Logger.warning("Failed to fetch publication #{at_uri}: #{inspect(reason)}")
        {:ok, nil}
    end
  end

  defp fetch_record(did, collection, rkey) do
    with {:ok, pds_url} <- resolve_pds_endpoint(did) do
      client = Exosphere.XRPC.Client.new(pds_url)

      case Exosphere.XRPC.Client.query(client, "com.atproto.repo.getRecord",
             repo: did,
             collection: collection,
             rkey: rkey
           ) do
        {:ok, %{"value" => record}} -> {:ok, record}
        {:error, _} = error -> error
      end
    end
  end

  defp resolve_pds_endpoint(did) do
    case Exosphere.ATProto.Identity.DID.resolve(did) do
      {:ok, doc} ->
        pds = Enum.find(doc.service, fn s -> s.id == "#atproto_pds" end)

        if pds do
          {:ok, pds.service_endpoint}
        else
          {:error, :no_pds_service}
        end

      {:error, _} = error ->
        error
    end
  end

  defp parse_at_uri(at_uri) do
    case Regex.run(~r/^at:\/\/([^\/]+)\/([^\/]+)\/(.+)$/, at_uri) do
      [_, did, collection, rkey] -> {:ok, did, collection, rkey}
      _ -> {:error, :invalid_at_uri}
    end
  end

  defp extract_theme_color(record, key) do
    case get_in(record, ["basicTheme", key]) do
      %{"r" => r, "g" => g, "b" => b} -> rgb_to_hex(r, g, b)
      _ -> nil
    end
  end

  defp rgb_to_hex(r, g, b) do
    r_hex = r |> Integer.to_string(16) |> String.pad_leading(2, "0")
    g_hex = g |> Integer.to_string(16) |> String.pad_leading(2, "0")
    b_hex = b |> Integer.to_string(16) |> String.pad_leading(2, "0")
    "##{r_hex}#{g_hex}#{b_hex}"
  end

  defp get_blob_cid(%{"ref" => %{"$link" => cid}}), do: cid
  defp get_blob_cid(_), do: nil

  defp get_bsky_post_uri(%{"uri" => uri}), do: uri
  defp get_bsky_post_uri(_), do: nil

  defp build_full_url(nil, _path), do: nil
  defp build_full_url(site_url, nil), do: site_url
  defp build_full_url(site_url, path), do: site_url <> path

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> DateTime.truncate(dt, :second)
      {:error, _} -> nil
    end
  end
end
