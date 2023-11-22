defmodule LiveQuery.Core do
  alias LiveQuery.Core.Supervisor
  alias LiveQuery.Core.Store
  alias LiveQuery.Core.System
  alias LiveQuery.Core.Proxy

  defdelegate start_link(opts), to: Supervisor

  def start_using({system, key}), do: start_using(system, key)
  def start_using(system, key), do: Proxy.start_using(system, key)

  def stop_using({system, key}), do: stop_using(system, key)
  def stop_using(system, key), do: Proxy.stop_using(system, key)

  def subscribe({system, key}), do: subscribe(system, key)
  def subscribe(system, key), do: System.subscribe(system, "store:#{inspect(key)}")

  def unsubscribe({system, key}), do: unsubscribe(system, key)
  def unsubscribe(system, key), do: System.unsubscribe(system, "store:#{inspect(key)}")

  def get_data({system, key}), do: get_data(system, key)
  def get_data(system, key), do: Store.read(system, key)

  def set_data({system, key}, data), do: Store.set(system, key, data)

  def is_topic_for_key({system, key}, topic), do: is_topic_for_key(system, key, topic)

  def is_topic_for_key(system, key, topic) do
    "#{inspect(system)}:store:#{inspect(key)}" === topic
  end
end
