defmodule AtmosphereFeeds.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AtmosphereFeedsWeb.Telemetry,
      AtmosphereFeeds.Repo,
      {DNSCluster, query: Application.get_env(:atmosphere_feeds, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AtmosphereFeeds.PubSub},
      {Task.Supervisor, name: AtmosphereFeeds.TaskSupervisor},
      AtmosphereFeeds.Firehose.Consumer,
      AtmosphereFeedsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AtmosphereFeeds.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AtmosphereFeedsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
