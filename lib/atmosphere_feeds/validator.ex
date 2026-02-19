defmodule AtmosphereFeeds.Validator do
  @moduledoc """
  Validates publications and documents by verifying ownership through
  well-known endpoints and HTML link tags before ingestion.

  ## Publication Verification

  Fetches `/.well-known/site.standard.publication` from the publication's domain.
  The response body must match the publication's AT-URI.

  ## Document Verification

  Fetches the document's URL and checks for a `<link>` tag in the HTML that
  references the document's AT-URI:

      <link rel="site.standard.document" href="at://did:plc:xyz/site.standard.document/rkey">
  """

  require Logger

  @doc """
  Validates a publication by checking its `.well-known` endpoint.

  Fetches `{url}/.well-known/site.standard.publication` and verifies the
  response body matches the given AT-URI.
  """
  def validate_publication(at_uri, url) when is_binary(at_uri) and is_binary(url) do
    well_known_url =
      url
      |> String.trim_trailing("/")
      |> Kernel.<>("/.well-known/site.standard.publication")

    case Req.get(well_known_url, [retry: false] ++ req_options()) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        if String.trim(body) == at_uri do
          :ok
        else
          {:error, :publication_mismatch}
        end

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Publication validation failed for #{url}: HTTP #{status}")
        {:error, :well_known_not_found}

      {:error, exception} ->
        Logger.warning("Publication validation request failed for #{url}: #{inspect(exception)}")
        {:error, {:request_failed, exception}}
    end
  end

  def validate_publication(_at_uri, nil), do: {:error, :no_publication_url}

  @doc """
  Validates a document by checking for a link tag in its HTML.

  Fetches the document's URL and checks for:

      <link rel="site.standard.document" href="{at_uri}">
  """
  def validate_document(at_uri, full_url) when is_binary(at_uri) and is_binary(full_url) do
    case Req.get(full_url, [retry: false] ++ req_options()) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        if has_document_link_tag?(body, at_uri) do
          :ok
        else
          {:error, :document_link_missing}
        end

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Document validation failed for #{full_url}: HTTP #{status}")
        {:error, :document_not_found}

      {:error, exception} ->
        Logger.warning(
          "Document validation request failed for #{full_url}: #{inspect(exception)}"
        )

        {:error, {:request_failed, exception}}
    end
  end

  def validate_document(_at_uri, nil), do: {:error, :no_document_url}

  defp has_document_link_tag?(html, at_uri) do
    link_tags = Regex.scan(~r/<link\s[^>]*\/?>/i, html)

    Enum.any?(link_tags, fn [tag] ->
      has_rel = Regex.match?(~r/rel=["']site\.standard\.document["']/i, tag)

      has_href =
        String.contains?(tag, ~s(href="#{at_uri}")) or
          String.contains?(tag, ~s(href='#{at_uri}'))

      has_rel and has_href
    end)
  end

  defp req_options do
    Application.get_env(:atmosphere_feeds, __MODULE__, [])
  end
end
