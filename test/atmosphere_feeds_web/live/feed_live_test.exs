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
  end
end
