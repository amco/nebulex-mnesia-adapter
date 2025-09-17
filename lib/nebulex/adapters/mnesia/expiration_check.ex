defmodule Nebulex.Adapters.Mnesia.ExpirationCheck do
  use GenServer

  alias Nebulex.Adapters.Mnesia

  @default_ttl 60_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)

    schedule_check(ttl)

    {:ok, opts}
  end

  def schedule_check(time) do
    Process.send_after(self(), :clean_expired, time)
  end

  def handle_info(:clean_expired, state) do
    ttl = Keyword.get(state, :ttl, @default_ttl)

    Mnesia.clear_expired_keys()

    schedule_check(ttl)

    {:noreply, state}
  end
end
