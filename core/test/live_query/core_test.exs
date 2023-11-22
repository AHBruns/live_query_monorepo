defmodule LiveQuery.CoreTest do
  use SystemCase, async: true

  alias LiveQuery.Core

  test "setup", context do
    assert %{system: _, supervisor_pid: _} = context
  end

  test "stop_using no-op", %{system: system} do
    assert {:ok, 0} = Core.stop_using(system, :unused_key)
  end

  test "start_using a constant query", %{system: system} do
    key = %Queries.ConstantQuery{value: :query_value}
    assert :ok = Core.start_using(system, key)
    assert {:ok, :query_value} = Core.get_data(system, key)
  end

  test "stop_using a used constant query clears the store", %{system: system} do
    key = %Queries.ConstantQuery{value: :query_value}
    assert :ok = Core.start_using(system, key)
    assert {:ok, :query_value} = Core.get_data(system, key)
    assert {:ok, 0} = Core.stop_using(system, key)
    assert {:error, :not_found} = Core.get_data(system, key)
  end

  test "start_using is idempotent", %{system: system} do
    key = %Queries.ConstantQuery{value: :query_value}
    assert :ok = Core.start_using(system, key)
    assert :ok = Core.start_using(system, key)
    assert {:ok, :query_value} = Core.get_data(system, key)
  end

  test "stop_using is idempotent", %{system: system} do
    key = %Queries.ConstantQuery{value: :query_value}
    assert :ok = Core.start_using(system, key)
    assert {:ok, :query_value} = Core.get_data(system, key)
    assert {:ok, 0} = Core.stop_using(system, key)
    assert {:error, :not_found} = Core.get_data(system, key)
    assert {:ok, 0} = Core.stop_using(system, key)
    assert {:error, :not_found} = Core.get_data(system, key)
  end

  test "constant query emits pub sub event on mount and unmount", %{system: system} do
    key = %Queries.ConstantQuery{value: :query_value}
    Core.subscribe(system, key)
    assert :ok = Core.start_using(system, key)
    assert_received {_, :set}
    assert {:ok, 0} = Core.stop_using(system, key)
    assert_received {_, :unset}
  end

  test "constant query only emits pub sub event on mount once", %{system: system} do
    key = %Queries.ConstantQuery{value: :query_value}
    Core.subscribe(system, key)
    assert :ok = Core.start_using(system, key)
    assert_received {_, :set}
    assert :ok = Core.start_using(system, key)
    refute_received {_, :set}
  end

  test "non-constant query works", %{system: system} do
    key = %Queries.RandomNumberQuery{}
    Core.subscribe(system, key)
    assert :ok = Core.start_using(system, key)
    value_1 = Core.get_data(system, key)
    clear_mailbox()
    assert_receive {_, :set}
    value_2 = Core.get_data(system, key)
    assert value_1 !== value_2
  end

  test "unsubscribe unsubscribes", %{system: system} do
    key = %Queries.RandomNumberQuery{}
    Core.subscribe(system, key)
    assert :ok = Core.start_using(system, key)
    assert_receive {_, :set}
    Core.unsubscribe(system, key)
    clear_mailbox()
    refute_receive _
  end

  defp clear_mailbox() do
    receive do
      _ -> clear_mailbox()
    after
      0 -> :ok
    end
  end
end
