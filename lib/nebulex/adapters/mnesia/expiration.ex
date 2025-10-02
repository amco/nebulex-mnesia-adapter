defmodule Nebulex.Adapters.Mnesia.Expiration do
  @moduledoc """
  A GenServer that periodically cleans up expired keys from the Mnesia
  cache based on the `:cleanup_interval` configuration.

  ## Example

      config :my_app, MyApp.MnesiaCache,
        cleanup_interval: 1_000 * 60 * 60 * 2

  """

  use GenServer

  @doc "Default cleanup interval in milliseconds of 6 hours."
  @default_interval 1_000 * 60 * 60 * 6

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    interval = Keyword.get(opts, :cleanup_interval, @default_interval)
    schedule_cleanup(interval)
    {:ok, %{interval: interval}}
  end

  def handle_info(:clean, %{interval: interval} = state) do
    schedule_cleanup(interval)
    {:noreply, state}
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :clean, interval)
  end
end
