defmodule LiveQuery.Core.Store.ETS do
  use GenServer
  use LiveQuery.Core.Store

  alias LiveQuery.Core.Store

  @impl Store
  def start_link([]) do
    {:ok, pid} = GenServer.start_link(__MODULE__, [])
    {:ok, pid, GenServer.call(pid, :get_table)}
  end

  @impl GenServer
  def init([]) do
    {:ok, :ets.new(:table, [:public])}
  end

  @impl GenServer
  def handle_call(:get_table, _from, table) do
    {:reply, table, table}
  end

  @impl Store
  def read(table, key) do
    case :ets.lookup(table, key) do
      [] -> {:error, :not_found}
      [{^key, value}] -> {:ok, value}
    end
  end

  @impl Store
  def set(table, key, value) do
    true = :ets.insert(table, {key, value})
    {:ok, value}
  end

  @impl Store
  def unset(table, key) do
    true = :ets.delete(table, key)
    :ok
  end
end
