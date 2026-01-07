defmodule AtmosphereFeedsWeb.FeedLiveTest do
  use AtmosphereFeedsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias AtmosphereFeeds.Feeds
  alias AtmosphereFeeds.Repo

  describe "FeedLive" do
    test "displays documents from database", %{conn: conn} do
      {:ok, author} =
        Feeds.upsert_author(%{
          did: "did:plc:test",
          handle: "test.bsky.social",
          display_name: "Test Author"
        })

      {:ok, _doc} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:test/site.standard.document/abc",
          did: "did:plc:test",
          rkey: "abc",
          title: "Test Document Title",
          full_url: "https://example.com/test",
          description: "A test document description",
          published_at: DateTime.utc_now(),
          author_id: author.id
        })

      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Test Document Title"
      assert html =~ "Test Author"
      assert html =~ "A test document description"
    end

    test "shows empty state when no documents", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "No documents yet"
    end

    test "receives new documents via PubSub and updates view", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "No documents yet"

      {:ok, author} =
        Feeds.upsert_author(%{
          did: "did:plc:live",
          handle: "live.test",
          display_name: "Live Author"
        })

      {:ok, doc} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:live/site.standard.document/live123",
          did: "did:plc:live",
          rkey: "live123",
          title: "Live Update Document",
          full_url: "https://example.com/live",
          published_at: DateTime.utc_now(),
          author_id: author.id
        })

      doc = Repo.preload(doc, [:author, :publication])
      Feeds.broadcast_new_document(doc)

      updated_html = render(view)
      assert updated_html =~ "Live Update Document"
      assert updated_html =~ "Live Author"
    end

    test "displays document with link when full_url present", %{conn: conn} do
      {:ok, author} = Feeds.upsert_author(%{did: "did:plc:link", handle: "link.test"})

      {:ok, _doc} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:link/site.standard.document/linked",
          did: "did:plc:link",
          rkey: "linked",
          title: "Linked Document",
          full_url: "https://example.com/linked-page",
          published_at: DateTime.utc_now(),
          author_id: author.id
        })

      {:ok, _view, html} = live(conn, "/")

      assert html =~ "https://example.com/linked-page"
      assert html =~ "Linked Document"
    end

    test "displays author handle when no display name", %{conn: conn} do
      {:ok, author} =
        Feeds.upsert_author(%{
          did: "did:plc:handle",
          handle: "handleonly.bsky.social"
        })

      {:ok, _doc} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:handle/site.standard.document/noname",
          did: "did:plc:handle",
          rkey: "noname",
          title: "Handle Only Doc",
          published_at: DateTime.utc_now(),
          author_id: author.id
        })

      {:ok, _view, html} = live(conn, "/")

      assert html =~ "@handleonly.bsky.social"
    end

    test "displays document tags", %{conn: conn} do
      {:ok, author} = Feeds.upsert_author(%{did: "did:plc:tags", handle: "tags.test"})

      {:ok, _doc} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:tags/site.standard.document/tagged",
          did: "did:plc:tags",
          rkey: "tagged",
          title: "Tagged Document",
          tags: ["elixir", "phoenix", "liveview"],
          published_at: DateTime.utc_now(),
          author_id: author.id
        })

      {:ok, _view, html} = live(conn, "/")

      assert html =~ "elixir"
      assert html =~ "phoenix"
      assert html =~ "liveview"
    end

    test "filters documents by publication via URL param", %{conn: conn} do
      {:ok, author} = Feeds.upsert_author(%{did: "did:plc:filter", handle: "filter.test"})

      {:ok, pub1} =
        Feeds.upsert_publication(%{
          at_uri: "at://did:plc:filter/site.standard.publication/pub1",
          did: "did:plc:filter",
          rkey: "pub1",
          name: "Publication One",
          url: "https://pub-one.example.com",
          author_id: author.id
        })

      {:ok, pub2} =
        Feeds.upsert_publication(%{
          at_uri: "at://did:plc:filter/site.standard.publication/pub2",
          did: "did:plc:filter",
          rkey: "pub2",
          name: "Publication Two",
          url: "https://pub-two.example.com",
          author_id: author.id
        })

      {:ok, _doc1} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:filter/site.standard.document/doc1",
          did: "did:plc:filter",
          rkey: "doc1",
          title: "Doc in Pub One",
          published_at: DateTime.utc_now(),
          author_id: author.id,
          publication_id: pub1.id
        })

      {:ok, _doc2} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:filter/site.standard.document/doc2",
          did: "did:plc:filter",
          rkey: "doc2",
          title: "Doc in Pub Two",
          published_at: DateTime.utc_now(),
          author_id: author.id,
          publication_id: pub2.id
        })

      {:ok, _view, html} = live(conn, "/?publication=#{pub1.id}")

      assert html =~ "Doc in Pub One"
      refute html =~ "Doc in Pub Two"
      assert html =~ "Filtering by:"
      assert html =~ "Publication One"
    end

    test "clear filter link restores all documents", %{conn: conn} do
      {:ok, author} = Feeds.upsert_author(%{did: "did:plc:clear", handle: "clear.test"})

      {:ok, pub} =
        Feeds.upsert_publication(%{
          at_uri: "at://did:plc:clear/site.standard.publication/pubclear",
          did: "did:plc:clear",
          rkey: "pubclear",
          name: "Filtered Pub",
          url: "https://filtered.example.com",
          author_id: author.id
        })

      {:ok, _doc1} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:clear/site.standard.document/filtered",
          did: "did:plc:clear",
          rkey: "filtered",
          title: "Filtered Doc",
          published_at: DateTime.utc_now(),
          author_id: author.id,
          publication_id: pub.id
        })

      {:ok, _doc2} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:clear/site.standard.document/unfiltered",
          did: "did:plc:clear",
          rkey: "unfiltered",
          title: "Unfiltered Doc",
          published_at: DateTime.utc_now(),
          author_id: author.id
        })

      {:ok, view, html} = live(conn, "/?publication=#{pub.id}")
      assert html =~ "Filtered Doc"
      refute html =~ "Unfiltered Doc"

      html = view |> element("a", "Clear filter") |> render_click()

      assert html =~ "Filtered Doc"
      assert html =~ "Unfiltered Doc"
      refute html =~ "Filtering by:"
    end

    test "live updates respect publication filter", %{conn: conn} do
      {:ok, author} = Feeds.upsert_author(%{did: "did:plc:livefilter", handle: "livefilter.test"})

      {:ok, pub} =
        Feeds.upsert_publication(%{
          at_uri: "at://did:plc:livefilter/site.standard.publication/livepub",
          did: "did:plc:livefilter",
          rkey: "livepub",
          name: "Live Pub",
          url: "https://live.example.com",
          author_id: author.id
        })

      {:ok, view, _html} = live(conn, "/?publication=#{pub.id}")

      {:ok, matching_doc} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:livefilter/site.standard.document/matching",
          did: "did:plc:livefilter",
          rkey: "matching",
          title: "Matching Live Doc",
          published_at: DateTime.utc_now(),
          author_id: author.id,
          publication_id: pub.id
        })

      {:ok, other_doc} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:livefilter/site.standard.document/other",
          did: "did:plc:livefilter",
          rkey: "other",
          title: "Other Live Doc",
          published_at: DateTime.utc_now(),
          author_id: author.id
        })

      matching_doc = Repo.preload(matching_doc, [:author, :publication])
      other_doc = Repo.preload(other_doc, [:author, :publication])

      Feeds.broadcast_new_document(matching_doc)
      Feeds.broadcast_new_document(other_doc)

      html = render(view)
      assert html =~ "Matching Live Doc"
      refute html =~ "Other Live Doc"
    end
  end
end
