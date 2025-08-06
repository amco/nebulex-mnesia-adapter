defmodule NebulexMnesiaAdapterTest do
  use ExUnit.Case, async: true
  use NebulexMnesiaAdapter.CacheTest

  alias NebulexMnesiaAdapter.TestCache, as: Cache

  setup do
    pid =
      case Cache.start_link() do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

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
