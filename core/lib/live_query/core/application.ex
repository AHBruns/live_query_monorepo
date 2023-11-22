defmodule LiveQuery.Core.Application do
  use Application

  @impl Application
  def start(_type, _args) do
    Supervisor.start_link(
      [
        {
          Registry,
          keys: :unique, name: LiveQuery.Core.Names, partitions: System.schedulers_online()
        },
        {
          Registry,
          keys: :unique, name: LiveQuery.Core.PubSub, partitions: System.schedulers_online()
        }
      ],
      strategy: :one_for_one
    )
  end
end
