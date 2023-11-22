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
       keys_and_consumer_pids: BiMultiMap.new(),
       keys_and_start_tasks: BiMap.new(),
       start_tasks_and_consumer_pids: BiMultiMap.new(),
       start_tasks_and_froms: BiMultiMap.new()
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
  def handle_call({consumer_pid, :start_using, key}, from, state) do
    cond do
      BiMap.has_key?(state.keys_and_query_pids, key) ->
        state = attach(state, consumer_pid, key)
        {:reply, :ok, state}

      BiMap.has_key?(state.keys_and_start_tasks, key) ->
        state =
          Map.update!(state, :start_tasks_and_consumer_pids, fn start_tasks_and_consumer_pids ->
            BiMultiMap.put(
              start_tasks_and_consumer_pids,
              BiMap.fetch!(state.keys_and_start_tasks, key),
              consumer_pid
            )
          end)
          |> Map.update!(:start_tasks_and_froms, fn start_tasks_and_froms ->
            BiMultiMap.put(
              start_tasks_and_froms,
              BiMap.fetch!(state.keys_and_start_tasks, key),
              from
            )
          end)

        {:noreply, state}

      true ->
        %Task{ref: task_ref, pid: pid} =
          Task.async(fn -> start_query(state, key) end)

        state =
          state
          |> Map.update!(:pids_and_monitors, &BiMap.put(&1, pid, task_ref))
          |> Map.update!(:keys_and_start_tasks, &BiMap.put(&1, key, task_ref))
          |> Map.update!(:start_tasks_and_consumer_pids, fn start_tasks_and_consumer_pids ->
            BiMultiMap.put(start_tasks_and_consumer_pids, task_ref, consumer_pid)
          end)
          |> Map.update!(:start_tasks_and_froms, fn start_tasks_and_froms ->
            BiMultiMap.put(start_tasks_and_froms, task_ref, from)
          end)

        {:noreply, state}
    end
  end

  def handle_call({consumer_pid, :stop_using, key}, _from, state) do
    if BiMap.has_value?(state.keys_and_start_tasks, key) and
         BiMultiMap.member?(
           state.start_tasks_and_consumer_pids,
           BiMap.fetch!(state.keys_and_start_tasks, key),
           consumer_pid
         ) do
      # If a consumer tries to stop using a key while they are in the process of starting
      # to use said key, we ignore their :stop_using request / act as if it came in
      # before their :start_using request.
      {:reply, :ok, state}
    else
      state = detach(state, consumer_pid, key)

      remaining_count =
        state.keys_and_consumer_pids
        |> BiMultiMap.get(consumer_pid)
        |> Enum.count()

      {:reply, {:ok, remaining_count}, state}
    end
  end

  @impl GenServer
  def handle_info({:EXIT, _pid, reason}, state) do
    {:stop, reason, state}
  end

  def handle_info({ref, {:ok, pid}}, state) do
    Process.demonitor(ref, [:flush])

    task_pid = BiMap.fetch_key!(state.pids_and_monitors, ref)
    Process.unlink(task_pid)

    receive do
      {:EXIT, ^task_pid, _} -> true
    after
      0 -> true
    end

    key = BiMap.fetch_key!(state.keys_and_start_tasks, ref)
    froms = BiMultiMap.get(state.start_tasks_and_froms, ref)
    consumer_pids = BiMultiMap.get(state.start_tasks_and_consumer_pids, ref)

    state =
      state
      |> Map.update!(:pids_and_monitors, &BiMap.delete_value(&1, ref))
      |> Map.update!(:keys_and_query_pids, &BiMap.put(&1, key, pid))
      |> Map.update!(:keys_and_start_tasks, &BiMap.delete_key(&1, key))
      |> Map.update!(:start_tasks_and_consumer_pids, &BiMultiMap.delete_key(&1, ref))
      |> Map.update!(:start_tasks_and_froms, &BiMultiMap.delete_key(&1, ref))
      |> monitoring(pid)
      |> then(fn state -> Enum.reduce(consumer_pids, state, &attach(&2, &1, key)) end)

    Enum.each(froms, &GenServer.reply(&1, :ok))

    {:noreply, state}
  end

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

        # If a query stops while it still has consumers, that's a bug on the implementer's part.
        # We handle it by sending an exit signal to all of its consumers.

        state.keys_and_consumer_pids
        |> BiMultiMap.get(key)
        |> Enum.each(fn consumer_pid -> Process.exit(consumer_pid, {:query_down, key}) end)

        state
        |> Map.update!(:keys_and_consumer_pids, &BiMultiMap.delete_key(&1, key))
        |> Map.update!(:keys_and_query_pids, &BiMap.delete_key(&1, key))
      else
        state
      end

    {:noreply, monitoring(state, pid)}
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
