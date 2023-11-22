defmodule LiveQuery.Core.Store do
  # CONTRACT

  @callback start_link(term()) :: {:ok, pid(), term()}
  @callback read(system :: atom(), key :: term()) :: {:ok, term()} | {:error, :not_found}
  @callback set(system :: atom(), key :: term(), value) :: {:ok, value} when value: term()
  @callback unset(system :: atom(), key :: term()) :: :ok

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour LiveQuery.Core.Store

      def child_spec(system) do
        default = %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [system]}
        }

        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end

      defoverridable child_spec: 1
    end
  end

  # API

  alias LiveQuery.Core.System
  alias LiveQuery.Core.Config

  def child_spec(system) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [system]}
    }
  end

  def start_link(system) do
    store_module = Config.read(system, :store)
    {:ok, pid, name} = store_module.start_link([])
    {:ok, _} = System.register(system, store_module, name)
    {:ok, pid}
  end

  def read(system, key) do
    store_module = Config.read(system, :store)
    {:ok, name} = System.lookup(system, store_module)
    store_module.read(name, key)
  end

  def set(system, key, value) do
    store_module = Config.read(system, :store)
    {:ok, name} = System.lookup(system, store_module)
    store_module.set(name, key, value)
    :ok = System.broadcast(system, "store:#{inspect(key)}", :set)
  end

  def unset(system, key) do
    store_module = Config.read(system, :store)
    {:ok, name} = System.lookup(system, store_module)
    store_module.unset(name, key)
    :ok = System.broadcast(system, "store:#{inspect(key)}", :unset)
  end
end
