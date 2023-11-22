defmodule SystemCase do
  use ExUnit.CaseTemplate

  setup context do
    system = {context.module, context.test}
    {:ok, supervisor_pid} = LiveQuery.Core.start_link(system: system)
    [system: system, supervisor_pid: supervisor_pid]
  end
end
