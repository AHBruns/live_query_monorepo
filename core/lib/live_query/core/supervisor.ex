defmodule LiveQuery.Core.Supervisor do
  use Supervisor

  alias LiveQuery.Core.Config
  alias LiveQuery.Core.Store
  alias LiveQuery.Core.Proxy

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    system = Keyword.fetch!(opts, :system)

    Supervisor.init(
      [
        {Config, system: system, store: Keyword.get(opts, :store, LiveQuery.Core.Store.ETS)},
        {Store, system},
        {DynamicSupervisor, name: LiveQuery.Core.System.via(system, :query_supervisor)},
        {Proxy, system}
      ],
      strategy: :rest_for_one
    )
  end
end
