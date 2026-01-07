defmodule AtmosphereFeedsWeb.FeedControllerTest do
  use AtmosphereFeedsWeb.ConnCase

  alias AtmosphereFeeds.Feeds

  describe "GET /feed.atom" do
    test "returns valid Atom XML", %{conn: conn} do
      conn = get(conn, ~p"/feed.atom")

      assert response_content_type(conn, :xml)
      body = response(conn, 200)
      assert body =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
      assert body =~ ~s(<feed xmlns="http://www.w3.org/2005/Atom">)
      assert body =~ "<title>Atmosphere Feed</title>"
    end

    test "includes documents in feed", %{conn: conn} do
      {:ok, pub} =
        Feeds.upsert_publication(%{
          at_uri: "at://did:plc:test123/site.standard.publication/pub1",
          did: "did:plc:test123",
          rkey: "pub1",
          name: "Test Pub",
          url: "https://test.example.com"
        })

      {:ok, _doc} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:test123/site.standard.document/doc1",
          did: "did:plc:test123",
          rkey: "doc1",
          publication_id: pub.id,
          title: "Test Document",
          published_at: DateTime.utc_now()
        })

      conn = get(conn, ~p"/feed.atom")
      body = response(conn, 200)

      assert body =~ "<title>Test Document</title>"
      assert body =~ "<entry>"
    end

    test "filters by publication when param provided", %{conn: conn} do
      {:ok, pub1} =
        Feeds.upsert_publication(%{
          at_uri: "at://did:plc:a/site.standard.publication/p1",
          did: "did:plc:a",
          rkey: "p1",
          name: "Pub One",
          url: "https://pub-one.example.com"
        })

      {:ok, pub2} =
        Feeds.upsert_publication(%{
          at_uri: "at://did:plc:b/site.standard.publication/p2",
          did: "did:plc:b",
          rkey: "p2",
          name: "Pub Two",
          url: "https://pub-two.example.com"
        })

      {:ok, _} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:a/site.standard.document/d1",
          did: "did:plc:a",
          rkey: "d1",
          publication_id: pub1.id,
          title: "Doc in Pub One",
          published_at: DateTime.utc_now()
        })

      {:ok, _} =
        Feeds.upsert_document(%{
          at_uri: "at://did:plc:b/site.standard.document/d2",
          did: "did:plc:b",
          rkey: "d2",
          publication_id: pub2.id,
          title: "Doc in Pub Two",
          published_at: DateTime.utc_now()
        })

      conn = get(conn, ~p"/feed.atom?publication=#{pub1.id}")
      body = response(conn, 200)

      assert body =~ "Doc in Pub One"
      refute body =~ "Doc in Pub Two"
      assert body =~ "<title>Pub One - Atmosphere Feed</title>"
    end

    test "includes logo when publication has icon_cid", %{conn: conn} do
      {:ok, pub} =
        Feeds.upsert_publication(%{
          at_uri: "at://did:plc:icontest/site.standard.publication/p1",
          did: "did:plc:icontest",
          rkey: "p1",
          name: "Pub With Icon",
          url: "https://icon.example.com",
          icon_cid: "bafkreiabc123"
        })

      conn = get(conn, ~p"/feed.atom?publication=#{pub.id}")
      body = response(conn, 200)

      assert body =~
               "<logo>https://cdn.bsky.app/img/feed_thumbnail/plain/did:plc:icontest/bafkreiabc123@jpeg</logo>"

      assert body =~
               "<icon>https://cdn.bsky.app/img/avatar_thumbnail/plain/did:plc:icontest/bafkreiabc123@jpeg</icon>"
    end
  end
end
