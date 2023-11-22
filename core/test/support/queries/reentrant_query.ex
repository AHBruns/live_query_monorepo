defmodule Queries.ReentrantQuery do
  defstruct [:num]

  use GenServer

  alias LiveQuery.Core.KeyLike
  alias LiveQuery.Core

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    if opts.key.num === 0 do
      Core.set_data(opts.data_ref, 0)
      {:ok, nil}
    else
      Core.set_data(opts.data_ref, :loading)
      {:ok, %{opts: opts}, {:continue, opts}}
    end
  end

  @impl true
  def handle_continue(_, state) do
    state = Map.put(state, :dep_key, %__MODULE__{num: state.opts.key.num - 1})
    Core.subscribe(state.opts.system, state.dep_key)
    Core.start_using(state.opts.system, state.dep_key)
    {:noreply, state}
  end

  @impl true
  def handle_info({_, :set}, state) do
    {:ok, value} = Core.get_data(state.opts.system, state.dep_key)
    if is_integer(value), do: Core.set_data(state.opts.data_ref, value + 1)
    {:noreply, state}
  end

  defimpl KeyLike do
    alias Queries.ReentrantQuery

    def child_spec(%ReentrantQuery{} = key, opts) do
      %{
        id: key,
        start: {ReentrantQuery, :start_link, [opts]}
      }
    end
  end
end
