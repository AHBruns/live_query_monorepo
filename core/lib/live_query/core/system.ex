defmodule LiveQuery.Core.System do
  def register(system, key, value) do
    {:ok, _} = Registry.register(LiveQuery.Core.Names, {system, key}, value)
    {:ok, value}
  end

  def lookup(system, key) do
    [{_pid, value}] = Registry.lookup(LiveQuery.Core.Names, {system, key})
    {:ok, value}
  end

  def via(system, key) do
    {:via, Registry, {LiveQuery.Core.Names, {system, key}}}
  end

  def subscribe(system, topic) do
    {:ok, _} = Registry.register(LiveQuery.Core.PubSub, {system, topic}, [])
    :ok
  end

  def unsubscribe(system, topic) do
    :ok = Registry.unregister(LiveQuery.Core.PubSub, {system, topic})
  end

  def broadcast(system, topic, event) do
    :ok =
      Registry.dispatch(
        LiveQuery.Core.PubSub,
        {system, topic},
        &Enum.each(&1, fn {pid, _} -> send(pid, {"#{inspect(system)}:#{topic}", event}) end)
      )
  end
end
