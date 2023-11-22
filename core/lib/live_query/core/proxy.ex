defmodule LiveQuery.Core.Proxy do
  use GenServer, shutdown: :infinity

  alias LiveQuery.Core.System
  alias LiveQuery.Core.Store
  alias LiveQuery.Core.KeyLike

  ### API

  def start_link(system) do
    GenServer.start_link(__MODULE__, system, name: System.via(system, __MODULE__))
  end

  def start_using(system, consumer_pid \\ self(), key) do
    GenServer.call(System.via(system, __MODULE__), {consumer_pid, :start_using, key})
  end

  def stop_using(system, consumer_pid \\ self(), key) do
    GenServer.call(System.via(system, __MODULE__), {consumer_pid, :stop_using, key})
  end

  ### IMPL

  @impl GenServer
  def init(system) do
    Process.flag(:trap_exit, true)

    {:ok,
     %{
       system: system,
       pids_and_monitors: BiMap.new(),
       keys_and_query_pids: BiMap.new(),
       keys_and_consumer_pids: BiMultiMap.new()
     }}
  end

  @impl GenServer
  def terminate(_reason, state) do
    state.keys_and_query_pids
    |> BiMap.to_list()
    |> Enum.each(fn {key, pid} ->
      stop_query(state, pid)
      Store.unset(state.system, key)
    end)
  end

  @impl GenServer
  def handle_call({consumer_pid, :start_using, key}, _from, state) do
    state =
      if BiMap.has_key?(state.keys_and_query_pids, key) do
        attach(state, consumer_pid, key)
      else
        {:ok, pid} = start_query(state, key)

        state
        |> Map.update!(:keys_and_query_pids, &BiMap.put(&1, key, pid))
        |> attach(consumer_pid, key)
        |> monitoring(pid)
      end

    {:reply, :ok, state}
  end

  def handle_call({consumer_pid, :stop_using, key}, _from, state) do
    state = detach(state, consumer_pid, key)

    key_count =
      state.keys_and_consumer_pids
      |> BiMultiMap.get(consumer_pid)
      |> Enum.count()

    {:reply, {:ok, key_count}, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    state =
      if BiMultiMap.has_value?(state.keys_and_consumer_pids, pid) do
        # consumer stopped
        state.keys_and_consumer_pids
        |> BiMultiMap.get_keys(pid)
        |> Enum.reduce(state, &detach(&2, pid, &1))
      else
        state
      end

    state =
      if BiMap.has_value?(state.keys_and_query_pids, pid) do
        # query stopped
        key = BiMap.fetch_key!(state.keys_and_query_pids, pid)
        Store.unset(state.system, key)

        state.keys_and_consumer_pids
        |> BiMultiMap.get(key)
        |> Enum.each(fn consumer_pid ->
          # If a query stops while it still has consumers, that's a bug on the implementer's part.
          # We handle it by sending a non-normal exit signal to all of its consumers.
          Process.exit(consumer_pid, {:query_down, key})
        end)

        state
        |> Map.update!(:keys_and_consumer_pids, &BiMultiMap.delete_key(&1, key))
        |> Map.update!(:keys_and_query_pids, &BiMap.delete_key(&1, key))
      else
        state
      end

    state = monitoring(state, pid)

    {:noreply, state}
  end

  defp attach(state, consumer_pid, key) do
    state
    |> Map.update!(:keys_and_consumer_pids, fn keys_and_consumer_pids ->
      BiMultiMap.put(keys_and_consumer_pids, key, consumer_pid)
    end)
    |> monitoring(consumer_pid)
  end

  defp detach(state, consumer_pid, key) do
    if BiMultiMap.member?(state.keys_and_consumer_pids, key, consumer_pid) do
      state =
        state
        |> Map.update!(:keys_and_consumer_pids, fn keys_and_consumer_pids ->
          BiMultiMap.delete(keys_and_consumer_pids, key, consumer_pid)
        end)
        |> monitoring(consumer_pid)

      if not BiMultiMap.has_key?(state.keys_and_consumer_pids, key) do
        query_pid = BiMap.fetch!(state.keys_and_query_pids, key)
        stop_query(state, query_pid)
        Store.unset(state.system, BiMap.fetch_key!(state.keys_and_query_pids, query_pid))
        monitoring(state, query_pid)
      else
        state
      end
    else
      state
    end
  end

  defp monitoring(state, pid) do
    cond do
      BiMap.has_key?(state.pids_and_monitors, pid) and
        not BiMultiMap.has_value?(state.keys_and_consumer_pids, pid) and
          not BiMap.has_value?(state.keys_and_query_pids, pid) ->
        state.pids_and_monitors
        |> BiMap.fetch!(pid)
        |> Process.demonitor([:flush])

        Map.update!(state, :pids_and_monitors, &BiMap.delete_key(&1, pid))

      not BiMap.has_key?(state.pids_and_monitors, pid) and
          (BiMultiMap.has_value?(state.keys_and_consumer_pids, pid) or
             BiMap.has_value?(state.keys_and_query_pids, pid)) ->
        monitor_ref = Process.monitor(pid)
        Map.update!(state, :pids_and_monitors, &BiMap.put(&1, pid, monitor_ref))

      true ->
        state
    end
  end

  defp start_query(state, key) do
    state.system
    |> LiveQuery.Core.System.via(:query_supervisor)
    |> DynamicSupervisor.start_child(
      KeyLike.child_spec(
        key,
        %{
          system: state.system,
          key: key,
          data_ref: {state.system, key}
        }
      )
    )
  end

  defp stop_query(state, pid) do
    state.system
    |> LiveQuery.Core.System.via(:query_supervisor)
    |> DynamicSupervisor.terminate_child(pid)
  end
end
