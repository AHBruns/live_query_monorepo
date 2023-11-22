defmodule Queries.RandomNumberQuery do
  defstruct [:nonce]

  use GenServer

  alias LiveQuery.Core.KeyLike
  alias LiveQuery.Core

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    Core.set_data(opts.data_ref, System.unique_integer())
    send(self(), :tick)
    {:ok, opts}
  end

  @impl true
  def handle_info(:tick, opts) do
    Core.set_data(opts.data_ref, System.unique_integer())
    send(self(), :tick)
    {:noreply, opts}
  end

  defimpl KeyLike do
    alias Queries.RandomNumberQuery

    def child_spec(%RandomNumberQuery{}, opts) do
      RandomNumberQuery.child_spec(opts)
    end
  end
end
