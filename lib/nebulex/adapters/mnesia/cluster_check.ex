defmodule Nebulex.Adapters.Mnesia.ClusterCheck do
  use GenServer

  alias Nebulex.Adapters.Mnesia

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    schedule_check()

    {:ok, state}
  end

  def schedule_check(time \\ 60_000) do
    Process.send_after(self(), :check_cluster, time)
  end

  def handle_info(:check_cluster, state) do
    Mnesia.check_cluster()

    schedule_check()

    {:noreply, state}
  end
end
