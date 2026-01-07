defmodule AtmosphereFeedsWeb.FeedXML do
  @moduledoc """
  Generates Atom XML feed.
  """

  def render("index.xml", assigns) do
    documents = assigns[:documents] || []
    publication = assigns[:publication]
    base_url = AtmosphereFeedsWeb.Endpoint.url()

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>#{escape(feed_title(publication))}</title>
      <link href="#{feed_html_url(base_url, publication)}" rel="alternate" type="text/html"/>
      <link href="#{feed_self_url(base_url, publication)}" rel="self" type="application/atom+xml"/>
      <id>#{feed_id(publication)}</id>
      <updated>#{feed_updated(documents)}</updated>
      <subtitle>Latest posts from the Atmosphere feed</subtitle>
    #{feed_logo(publication)}#{Enum.map_join(documents, "\n", &entry_xml(&1, base_url))}</feed>
    """
  end

  defp entry_xml(document, base_url) do
    link = document.full_url || "#{base_url}/"

    """
      <entry>
        <title>#{escape(document.title)}</title>
        <link href="#{escape(link)}" rel="alternate" type="text/html"/>
        <id>#{entry_id(document)}</id>
        <published>#{to_iso8601(document.published_at)}</published>
        <updated>#{to_iso8601(document.updated_at)}</updated>
        <author>
          <name>#{escape(author_name(document.author))}</name>
        </author>
    #{summary_xml(document)}#{content_xml(document)}  </entry>
    """
  end

  defp summary_xml(%{description: desc}) when is_binary(desc) and desc != "" do
    "    <summary type=\"text\">#{escape(desc)}</summary>\n"
  end

  defp summary_xml(_), do: ""

  defp content_xml(%{text_content: content}) when is_binary(content) and content != "" do
    "    <content type=\"text\">#{escape(content)}</content>\n"
  end

  defp content_xml(_), do: ""

  defp feed_title(nil), do: "Atmosphere Feed"
  defp feed_title(publication), do: "#{publication.name} - Atmosphere Feed"

  defp feed_id(nil), do: "tag:atmosphere.feeds,2024:feed"
  defp feed_id(publication), do: "tag:atmosphere.feeds,2024:publication:#{publication.id}"

  defp feed_html_url(base_url, nil), do: "#{base_url}/"
  defp feed_html_url(base_url, pub), do: "#{base_url}/?publication=#{pub.id}"

  defp feed_self_url(base_url, nil), do: "#{base_url}/feed.atom"
  defp feed_self_url(base_url, pub), do: "#{base_url}/feed.atom?publication=#{pub.id}"

  defp feed_logo(nil), do: ""
  defp feed_logo(%{icon_cid: nil}), do: ""
  defp feed_logo(%{icon_cid: ""}), do: ""

  defp feed_logo(%{did: did, icon_cid: cid}) do
    logo = "https://cdn.bsky.app/img/feed_thumbnail/plain/#{did}/#{cid}@jpeg"
    icon = "https://cdn.bsky.app/img/avatar_thumbnail/plain/#{did}/#{cid}@jpeg"
    "  <logo>#{logo}</logo>\n  <icon>#{icon}</icon>\n"
  end

  defp feed_updated([]), do: DateTime.utc_now() |> DateTime.to_iso8601()
  defp feed_updated([doc | _]), do: to_iso8601(doc.updated_at)

  defp to_iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp to_iso8601(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt) <> "Z"

  defp entry_id(document), do: "tag:atmosphere.feeds,2024:document:#{document.id}"

  defp author_name(nil), do: "Unknown"
  defp author_name(%{display_name: name}) when is_binary(name) and name != "", do: name
  defp author_name(%{handle: handle}) when is_binary(handle), do: "@#{handle}"
  defp author_name(_), do: "Unknown"

  defp escape(nil), do: ""

  defp escape(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
