defmodule AtmosphereFeeds.Firehose.Consumer do
  @moduledoc """
  Consumes the AT Protocol firehose and filters for site.standard.* records.
  """

  use GenServer
  require Logger

  alias AtmosphereFeeds.Firehose.Handler

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[Firehose] Starting consumer...")

    {:ok, pid} =
      Exosphere.ATProto.Firehose.Consumer.start_link(
        relay_url: "wss://bsky.network",
        cursor: nil,
        on_event: &Handler.on_event/2
      )

    {:ok, %{consumer_pid: pid}}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("[Firehose] Received message: #{inspect(msg)}")
    {:noreply, state}
  end
end
