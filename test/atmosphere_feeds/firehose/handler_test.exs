defmodule AtmosphereFeeds.Firehose.HandlerTest do
  use AtmosphereFeeds.DataCase, async: false
  use Patch

  alias AtmosphereFeeds.Firehose.Handler
  alias AtmosphereFeeds.Feeds

  @sample_did "did:plc:pb4ykaxogrktccvcyopt52tk"
  @sample_rkey "00000mk35dnox"

  @mock_profile %{
    "did" => @sample_did,
    "handle" => "koio.sh",
    "displayName" => "KOIOS",
    "avatar" =>
      "https://cdn.bsky.app/img/avatar/plain/#{@sample_did}/bafkreieh4e5ldizgo2ahtxfmh5decgybdodtczjwkwbbo5y3oq5nfd7rhy@jpeg"
  }

  @sample_document_record %{
    "$type" => "site.standard.document",
    "site" => "https://koio.sh",
    "title" => "Building in Public: The Stateful AI Series",
    "description" =>
      "Documenting the decision process and thought chain behind the stateful AI research series.",
    "publishedAt" => "2026-01-06T22:14:50.673Z",
    "textContent" => "## The Request\n\nOperator: \"Research and post about stateful ai\""
  }

  setup do
    Feeds.subscribe()
    :ok
  end

  describe "on_event/2 integration" do
    test "processes document commit and stores in database" do
      patch(Exosphere.ATProto.Bsky, :get_profile, {:ok, @mock_profile})

      patch(Exosphere.ATProto.CAR, :decode, fn _blocks ->
        {:ok, %{:fake_cid => @sample_document_record}}
      end)

      doc_at_uri = "at://#{@sample_did}/site.standard.document/#{@sample_rkey}"

      Req.Test.stub(AtmosphereFeeds.Validator, fn conn ->
        html =
          ~s(<html><head><link rel="site.standard.document" href="#{doc_at_uri}"></head><body></body></html>)

        conn
        |> Plug.Conn.put_resp_header("content-type", "text/html")
        |> Plug.Conn.send_resp(200, html)
      end)

      msg = %{
        type: :commit,
        repo: @sample_did,
        time: "2026-01-06T22:14:50.821Z",
        rev: "3mbry2ltqcc2l",
        ops: [%{path: "site.standard.document/#{@sample_rkey}", action: :create, cid: nil}],
        blocks: <<1, 2, 3>>
      }

      Handler.on_event(msg, %{})

      assert_receive {:new_document, doc}, 5000

      assert doc.title == "Building in Public: The Stateful AI Series"
      assert doc.full_url == "https://koio.sh"
      assert doc.did == @sample_did
      assert doc.rkey == @sample_rkey

      assert doc.author.handle == "koio.sh"
      assert doc.author.display_name == "KOIOS"

      assert Feeds.get_document_by_at_uri(doc.at_uri) != nil
    end

    test "processes publication commit and stores in database" do
      patch(Exosphere.ATProto.Bsky, :get_profile, {:ok, @mock_profile})

      publication_record = %{
        "$type" => "site.standard.publication",
        "url" => "https://example.com",
        "name" => "Test Publication",
        "description" => "A test publication",
        "basicTheme" => %{
          "background" => %{"r" => 255, "g" => 0, "b" => 128},
          "foreground" => %{"r" => 0, "g" => 0, "b" => 0}
        }
      }

      patch(Exosphere.ATProto.CAR, :decode, fn _blocks ->
        {:ok, %{:fake_cid => publication_record}}
      end)

      pub_at_uri = "at://#{@sample_did}/site.standard.publication/testpub"

      Req.Test.stub(AtmosphereFeeds.Validator, fn conn ->
        Plug.Conn.send_resp(conn, 200, pub_at_uri)
      end)

      msg = %{
        type: :commit,
        repo: @sample_did,
        ops: [%{path: "site.standard.publication/testpub", action: :create, cid: nil}],
        blocks: <<1, 2, 3>>
      }

      Handler.on_event(msg, %{})

      assert_receive {:new_publication, pub}, 5000

      assert pub.name == "Test Publication"
      assert pub.url == "https://example.com"
      assert pub.theme_background == "#FF0080"
      assert pub.theme_foreground == "#000000"
    end

    test "ignores non-site.standard collections" do
      msg = %{
        type: :commit,
        repo: "did:plc:test",
        ops: [%{path: "app.bsky.feed.post/abc", action: :create, cid: nil}],
        blocks: <<>>
      }

      Handler.on_event(msg, %{})

      refute_receive {:new_document, _}, 100
      refute_receive {:new_publication, _}, 100
    end

    test "ignores delete actions" do
      msg = %{
        type: :commit,
        repo: @sample_did,
        ops: [%{path: "site.standard.document/abc", action: :delete, cid: nil}],
        blocks: <<>>
      }

      Handler.on_event(msg, %{})

      refute_receive {:new_document, _}, 100
    end

    test "returns state unchanged for non-commit messages" do
      msg = %{type: :identity, did: "did:plc:test"}
      state = %{my: :state}

      assert Handler.on_event(msg, state) == state
    end

    test "handles author profile fetch failure gracefully" do
      patch(Exosphere.ATProto.Bsky, :get_profile, {:error, :not_found})

      patch(Exosphere.ATProto.CAR, :decode, fn _blocks ->
        {:ok, %{:fake_cid => @sample_document_record}}
      end)

      doc_at_uri = "at://#{@sample_did}/site.standard.document/fallback123"

      Req.Test.stub(AtmosphereFeeds.Validator, fn conn ->
        html =
          ~s(<html><head><link rel="site.standard.document" href="#{doc_at_uri}"></head><body></body></html>)

        conn
        |> Plug.Conn.put_resp_header("content-type", "text/html")
        |> Plug.Conn.send_resp(200, html)
      end)

      msg = %{
        type: :commit,
        repo: @sample_did,
        ops: [%{path: "site.standard.document/fallback123", action: :create, cid: nil}],
        blocks: <<1, 2, 3>>
      }

      Handler.on_event(msg, %{})

      assert_receive {:new_document, doc}, 5000

      assert doc.author.did == @sample_did
      assert doc.author.handle == nil
    end
  end
end
