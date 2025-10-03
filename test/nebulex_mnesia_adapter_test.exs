defmodule NebulexMnesiaAdapterTest do
  use ExUnit.Case
  use NebulexMnesiaAdapter.CacheTest

  alias NebulexMnesiaAdapter.TestCache, as: Cache

  setup do
    pid =
      case Cache.start_link(master_node: true) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    :mnesia.wait_for_tables([Cache], 5_000)
    Cache.delete_all()

    on_exit(fn -> safe_stop(pid) end)

    {:ok, cache: Cache, name: Cache}
  end

  defp safe_stop(pid) do
    :ok = Process.sleep(10)
    if Process.alive?(pid), do: Cache.stop(pid)
  catch
    :exit, _ -> :ok
  end
end
