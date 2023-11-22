defmodule LiveQuery.Core.Config do
  use GenServer

  alias LiveQuery.Core.System

  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  @impl true
  def init(state) do
    table = :table |> :ets.new([:protected])
    :ets.insert(table, state)
    {:ok, _} = state |> Keyword.fetch!(:system) |> System.register(__MODULE__, table)
    {:ok, nil}
  end

  def read(system, key) do
    {:ok, table} = system |> System.lookup(__MODULE__)
    [{^key, value}] = :ets.lookup(table, key)
    value
  end
end
