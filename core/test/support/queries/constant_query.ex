defmodule Queries.ConstantQuery do
  defstruct [:value]

  use GenServer

  alias LiveQuery.Core.KeyLike
  alias LiveQuery.Core

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    Core.set_data(opts.data_ref, opts.key.value)
    {:ok, nil}
  end

  defimpl KeyLike do
    alias Queries.ConstantQuery

    def child_spec(%ConstantQuery{}, opts) do
      ConstantQuery.child_spec(opts)
    end
  end
end
