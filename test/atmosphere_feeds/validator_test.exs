defmodule AtmosphereFeeds.ValidatorTest do
  use ExUnit.Case, async: false

  alias AtmosphereFeeds.Validator

  @publication_at_uri "at://did:plc:abc123/site.standard.publication/testrkey"
  @publication_url "https://example.com"
  @document_at_uri "at://did:plc:xyz789/site.standard.document/docrkey"
  @document_url "https://example.com/blog/my-post"

  describe "validate_publication/2" do
    test "returns :ok when .well-known response matches AT-URI" do
      Req.Test.stub(Validator, fn conn ->
        assert conn.request_path == "/.well-known/site.standard.publication"

        Plug.Conn.send_resp(conn, 200, @publication_at_uri)
      end)

      assert :ok = Validator.validate_publication(@publication_at_uri, @publication_url)
    end

    test "returns :ok when response has trailing whitespace" do
      Req.Test.stub(Validator, fn conn ->
        Plug.Conn.send_resp(conn, 200, @publication_at_uri <> "\n")
      end)

      assert :ok = Validator.validate_publication(@publication_at_uri, @publication_url)
    end

    test "returns error when .well-known response does not match AT-URI" do
      Req.Test.stub(Validator, fn conn ->
        Plug.Conn.send_resp(conn, 200, "at://did:plc:wrong/site.standard.publication/otherrkey")
      end)

      assert {:error, :publication_mismatch} =
               Validator.validate_publication(@publication_at_uri, @publication_url)
    end

    test "returns error when .well-known endpoint returns 404" do
      Req.Test.stub(Validator, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert {:error, :well_known_not_found} =
               Validator.validate_publication(@publication_at_uri, @publication_url)
    end

    test "returns error when .well-known endpoint returns 500" do
      Req.Test.stub(Validator, fn conn ->
        Plug.Conn.send_resp(conn, 500, "Internal Server Error")
      end)

      assert {:error, :well_known_not_found} =
               Validator.validate_publication(@publication_at_uri, @publication_url)
    end

    test "returns error when request fails" do
      Req.Test.stub(Validator, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, {:request_failed, _}} =
               Validator.validate_publication(@publication_at_uri, @publication_url)
    end

    test "returns error when URL is nil" do
      assert {:error, :no_publication_url} =
               Validator.validate_publication(@publication_at_uri, nil)
    end

    test "strips trailing slash from URL before building .well-known path" do
      Req.Test.stub(Validator, fn conn ->
        assert conn.request_path == "/.well-known/site.standard.publication"
        Plug.Conn.send_resp(conn, 200, @publication_at_uri)
      end)

      assert :ok =
               Validator.validate_publication(@publication_at_uri, "https://example.com/")
    end
  end

  describe "validate_document/2" do
    test "returns :ok when document has matching link tag" do
      html = """
      <html>
        <head>
          <link rel="site.standard.document" href="#{@document_at_uri}">
        </head>
        <body><p>Hello</p></body>
      </html>
      """

      Req.Test.stub(Validator, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/html")
        |> Plug.Conn.send_resp(200, html)
      end)

      assert :ok = Validator.validate_document(@document_at_uri, @document_url)
    end

    test "returns :ok when link tag has href before rel" do
      html = """
      <html>
        <head>
          <link href="#{@document_at_uri}" rel="site.standard.document">
        </head>
        <body></body>
      </html>
      """

      Req.Test.stub(Validator, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/html")
        |> Plug.Conn.send_resp(200, html)
      end)

      assert :ok = Validator.validate_document(@document_at_uri, @document_url)
    end

    test "returns :ok when link tag is self-closing" do
      html = """
      <html>
        <head>
          <link rel="site.standard.document" href="#{@document_at_uri}" />
        </head>
        <body></body>
      </html>
      """

      Req.Test.stub(Validator, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/html")
        |> Plug.Conn.send_resp(200, html)
      end)

      assert :ok = Validator.validate_document(@document_at_uri, @document_url)
    end

    test "returns :ok when link tag uses single quotes" do
      html = """
      <html>
        <head>
          <link rel='site.standard.document' href='#{@document_at_uri}'>
        </head>
        <body></body>
      </html>
      """

      Req.Test.stub(Validator, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/html")
        |> Plug.Conn.send_resp(200, html)
      end)

      assert :ok = Validator.validate_document(@document_at_uri, @document_url)
    end

    test "returns error when link tag is missing" do
      html = """
      <html>
        <head><title>My Post</title></head>
        <body><p>Content</p></body>
      </html>
      """

      Req.Test.stub(Validator, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/html")
        |> Plug.Conn.send_resp(200, html)
      end)

      assert {:error, :document_link_missing} =
               Validator.validate_document(@document_at_uri, @document_url)
    end

    test "returns error when link tag has wrong AT-URI" do
      html = """
      <html>
        <head>
          <link rel="site.standard.document" href="at://did:plc:wrong/site.standard.document/otherrkey">
        </head>
        <body></body>
      </html>
      """

      Req.Test.stub(Validator, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/html")
        |> Plug.Conn.send_resp(200, html)
      end)

      assert {:error, :document_link_missing} =
               Validator.validate_document(@document_at_uri, @document_url)
    end

    test "returns error when link tag has wrong rel value" do
      html = """
      <html>
        <head>
          <link rel="stylesheet" href="#{@document_at_uri}">
        </head>
        <body></body>
      </html>
      """

      Req.Test.stub(Validator, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/html")
        |> Plug.Conn.send_resp(200, html)
      end)

      assert {:error, :document_link_missing} =
               Validator.validate_document(@document_at_uri, @document_url)
    end

    test "returns error when document returns 404" do
      Req.Test.stub(Validator, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert {:error, :document_not_found} =
               Validator.validate_document(@document_at_uri, @document_url)
    end

    test "returns error when request fails" do
      Req.Test.stub(Validator, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, {:request_failed, _}} =
               Validator.validate_document(@document_at_uri, @document_url)
    end

    test "returns error when URL is nil" do
      assert {:error, :no_document_url} =
               Validator.validate_document(@document_at_uri, nil)
    end
  end
end
