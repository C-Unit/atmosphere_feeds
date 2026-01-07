defmodule AtmosphereFeedsWeb.FeedController do
  use AtmosphereFeedsWeb, :controller

  alias AtmosphereFeeds.Feeds

  def index(conn, params) do
    publication_id = params["publication"]
    documents = Feeds.list_recent_documents(50, publication_id: publication_id)
    publication = publication_id && Feeds.get_publication(publication_id)

    conn
    |> put_resp_content_type("application/atom+xml")
    |> put_view(AtmosphereFeedsWeb.FeedXML)
    |> render("index.xml", documents: documents, publication: publication)
  end
end
