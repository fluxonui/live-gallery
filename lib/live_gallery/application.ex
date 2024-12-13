defmodule LiveGallery.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LiveGalleryWeb.Telemetry,
      LiveGallery.Repo,
      {DNSCluster, query: Application.get_env(:live_gallery, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LiveGallery.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: LiveGallery.Finch},
      # Start a worker by calling: LiveGallery.Worker.start_link(arg)
      # {LiveGallery.Worker, arg},
      # Start to serve requests, typically the last entry
      LiveGalleryWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveGallery.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LiveGalleryWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
