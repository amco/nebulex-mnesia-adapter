defmodule Nebulex.Adapters.Mnesia.Expiration do
  @moduledoc """
  A GenServer that periodically cleans up expired keys from the Mnesia
  cache based on the `:cleanup_interval` configuration.

  ## Example

      config :my_app, MyApp.MnesiaCache,
        cleanup_interval: 1_000 * 60 * 60 * 2

  """

  use GenServer

  alias Nebulex.Adapters.Mnesia.Utils

  @doc "Default cleanup interval in milliseconds of 6 hours."
  @default_interval 1_000 * 60 * 60 * 6

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    cache = Keyword.fetch!(opts, :cache)
    interval = Keyword.get(opts, :cleanup_interval, @default_interval)
    schedule_cleanup(interval)
    {:ok, %{cache: cache, interval: interval}}
  end

  def handle_info(:clean, %{cache: cache, interval: interval} = state) do
    delete_expired_entries(cache)
    schedule_cleanup(interval)
    {:noreply, state}
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :clean, interval)
  end

  defp delete_expired_entries(cache) do
    query = [{:<, {:+, :"$3", :"$4"}, Utils.now()}]
    cache.delete_all(query)
  end
end
