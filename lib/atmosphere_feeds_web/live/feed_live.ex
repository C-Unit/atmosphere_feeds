defmodule AtmosphereFeedsWeb.FeedLive do
  use AtmosphereFeedsWeb, :live_view

  alias AtmosphereFeeds.Feeds

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Feeds.subscribe()
    {:ok, assign(socket, :page_title, "Feed")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    publication_id = params["publication"]
    publication = publication_id && Feeds.get_publication(publication_id)
    documents = Feeds.list_recent_documents(50, publication_id: publication_id)

    {:noreply,
     socket
     |> assign(:publication_filter, publication)
     |> stream(:documents, documents, reset: true)}
  end

  @impl true
  def handle_info({:new_document, document}, socket) do
    filter = socket.assigns.publication_filter

    if is_nil(filter) or document.publication_id == filter.id do
      {:noreply, stream_insert(socket, :documents, document, at: 0)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_publication, _publication}, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-4">
        <h1 class="text-2xl font-bold">Atmosphere Feed</h1>
        <p class="text-base-content/60">Real-time publications from the atmosphere</p>

        <%= if @publication_filter do %>
          <div class="alert alert-info">
            <span>Filtering by: <strong>{@publication_filter.name}</strong></span>
            <.link patch={~p"/"} class="btn btn-sm btn-ghost">Clear filter</.link>
          </div>
        <% end %>

        <div class="divider"></div>

        <div id="documents" phx-update="stream" class="space-y-4">
          <div id="documents-empty" class="hidden only:block text-center py-12 text-base-content/50">
            <p>No documents yet. Waiting for new publications...</p>
          </div>
          <div :for={{id, document} <- @streams.documents} id={id}>
            <.document_card document={document} />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp document_card(assigns) do
    ~H"""
    <article class="card bg-base-200 shadow-sm hover:shadow-md transition-shadow">
      <div class="card-body p-4">
        <div class="flex items-start gap-3">
          <%= if @document.author && @document.author.avatar_url do %>
            <img
              src={@document.author.avatar_url}
              alt=""
              class="w-10 h-10 rounded-full"
            />
          <% else %>
            <div class="w-10 h-10 rounded-full bg-base-300 flex items-center justify-center">
              <span class="text-base-content/50 text-sm">?</span>
            </div>
          <% end %>

          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 text-sm text-base-content/60">
              <span class="font-medium text-base-content">
                {author_name(@document.author)}
              </span>
              <%= if @document.publication do %>
                <span>in</span>
                <.link
                  patch={~p"/?publication=#{@document.publication.id}"}
                  class="text-primary hover:underline"
                >
                  {@document.publication.name}
                </.link>
              <% end %>
            </div>

            <h2 class="card-title text-lg mt-1">
              <%= if @document.full_url do %>
                <a
                  href={@document.full_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="hover:underline"
                >
                  {@document.title}
                </a>
              <% else %>
                {@document.title}
              <% end %>
            </h2>

            <%= if @document.description do %>
              <p class="text-base-content/70 mt-2 line-clamp-2">
                {@document.description}
              </p>
            <% end %>

            <div class="flex items-center gap-4 mt-3 text-sm text-base-content/50">
              <time datetime={DateTime.to_iso8601(@document.published_at)}>
                {format_time(@document.published_at)}
              </time>

              <%= if @document.tags != [] do %>
                <div class="flex gap-1">
                  <%= for tag <- Enum.take(@document.tags, 3) do %>
                    <span class="badge badge-sm badge-outline">{tag}</span>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </article>
    """
  end

  defp author_name(nil), do: "Unknown"
  defp author_name(%{display_name: name}) when is_binary(name) and name != "", do: name
  defp author_name(%{handle: handle}) when is_binary(handle), do: "@#{handle}"
  defp author_name(_), do: "Unknown"

  defp format_time(nil), do: ""

  defp format_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end
end
