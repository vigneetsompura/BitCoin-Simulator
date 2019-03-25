defmodule Project42.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    import Supervisor.Spec, warn: false

    children = [
      # Start the Ecto repository
      Project42.Repo,
      # Start the endpoint when the application starts
      Project42Web.Endpoint,
      # Starts a worker by calling: Project42.Worker.start_link(arg)
      # {Project42.Worker, arg},
      worker(Registry, [:unique, :process_registry])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Project42.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Project42Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
