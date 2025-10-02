defmodule Nebulex.Adapters.Mnesia do
  @moduledoc """
  This module implements a Nebulex cache adapter using Mnesia as the
  underlying storage mechanism. It provides functions for cache operations
  such as `get`, `put`, `delete`, and more, while also handling expiration
  of cache entries.

  ## Options

    * `:table` - The name of the Mnesia table to use..

    * `:cleanup_interval` - The interval in milliseconds for cleaning up expired
      entries. Defaults to `1_000 * 60 * 60 * 6` (6 hours).

  ## Example

      defmodule MyApp.MnesiaCache do
        use Nebulex.Cache,
          otp_app: :my_app,
          adapter: Nebulex.Adapters.Mnesia
      end

      config :my_app, MyApp.MnesiaCache,
        table: :my_cache_table,
        cleanup_interval: 1_000 * 60 * 60 * 6

  """

  # Provide Cache Implementation
  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.Entry
  @behaviour Nebulex.Adapter.Queryable

  alias __MODULE__.{Cluster, Expiration, Table, Entry, Utils}

  @impl true
  defmacro __before_compile__(_env), do: :ok

  @impl Nebulex.Adapter
  def init(opts) do
    cache = Keyword.fetch!(opts, :cache)
    table = Keyword.get(opts, :table, cache)

    children = [
      {Cluster, opts},
      {Expiration, opts}
    ]

    child_spec = %{
      id: __MODULE__.Supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one]]}
    }

    {:ok, child_spec, %{table: table}}
  end

  ## Nebulex.Adapter.Entry

  @impl Nebulex.Adapter.Entry
  def get(%{table: table}, key, _opts) do
    Table.transaction(fn ->
      with {:ok, entry} <- Table.read(table, key),
           {:ok, :active} <- Entry.status(entry) do
        Entry.value(entry)
      else
        {:error, :not_found} -> nil
        {:error, :expired} -> delete_and_return(table, key, nil)
      end
    end)
  end

  @impl Nebulex.Adapter.Entry
  def get_all(%{table: table}, keys, _opts) do
    Table.transaction(fn ->
      Enum.reduce(keys, %{}, fn key, acc ->
        with {:ok, entry} <- Table.read(table, key),
             {:ok, :active} <- Entry.status(entry) do
          Map.put(acc, key, Entry.value(entry))
        else
          {:error, :not_found} -> acc
          {:error, :expired} -> delete_and_return(table, key, acc)
        end
      end)
    end)
  end

  @impl Nebulex.Adapter.Entry
  def put(%{table: table}, key, value, ttl, :put, _opts) do
    Table.transaction(fn ->
      :ok == Table.write(table, key, value, Utils.now(), ttl)
    end)
  end

  def put(adapter_meta, key, value, ttl, :put_new, opts) do
    case has_key?(adapter_meta, key) do
      false -> put(adapter_meta, key, value, ttl, :put, opts)
      true -> false
    end
  end

  def put(adapter_meta, key, value, ttl, :replace, opts) do
    case has_key?(adapter_meta, key) do
      true -> put(adapter_meta, key, value, ttl, :put, opts)
      false -> false
    end
  end

  @impl Nebulex.Adapter.Entry
  def put_all(adapter_meta, entries, ttl, :put, opts) do
    Table.transaction(fn ->
      Enum.all?(entries, fn {key, value} ->
        put(adapter_meta, key, value, ttl, :put, opts)
      end)
    end)
  end

  def put_all(adapter_meta, entries, ttl, :put_new, opts) do
    Table.transaction(fn ->
      Enum.all?(entries, fn {key, value} ->
        put(adapter_meta, key, value, ttl, :put_new, opts)
      end)
    end)
  end

  @impl Nebulex.Adapter.Entry
  def delete(%{table: table}, key, _opts) do
    Table.transaction(fn ->
      Table.delete(table, key)
    end)
  end

  @impl Nebulex.Adapter.Entry
  def take(%{table: table}, key, _opts) do
    Table.transaction(fn ->
      with {:ok, entry} <- Table.read(table, key),
           {:ok, :active} <- Entry.status(entry) do
        delete_and_return(table, key, Entry.value(entry))
      else
        {:error, :not_found} -> nil
        {:error, :expired} -> delete_and_return(table, key, nil)
      end
    end)
  end

  @impl Nebulex.Adapter.Entry
  def update_counter(%{table: table} = adapter_meta, key, amount, ttl, default, opts) do
    counter = get_new_counter_value(table, key, amount, default)
    put(adapter_meta, key, counter, ttl, :put, opts)
    counter
  end

  defp get_new_counter_value(table, key, amount, default) do
    Table.transaction(fn ->
      with {:ok, entry} <- Table.read(table, key),
           {:ok, :active} <- Entry.status(entry) do
        Entry.value(entry) + amount
      else
        {:error, :not_found} -> default + amount
        {:error, :expired} -> default + amount
      end
    end)
  end

  @impl Nebulex.Adapter.Entry
  def has_key?(%{table: table}, key) do
    Table.transaction(fn ->
      with {:ok, entry} <- Table.read(table, key),
           {:ok, :active} <- Entry.status(entry) do
        true
      else
        {:error, :not_found} -> false
        {:error, :expired} -> delete_and_return(table, key, false)
      end
    end)
  end

  @impl Nebulex.Adapter.Entry
  def ttl(%{table: table}, key) do
    Table.transaction(fn ->
      with {:ok, entry} <- Table.read(table, key),
           {:ok, :active} <- Entry.status(entry) do
        Entry.remaining_ttl(entry)
      else
        {:error, :not_found} -> nil
        {:error, :expired} -> nil
      end
    end)
  end

  @impl Nebulex.Adapter.Entry
  def expire(%{table: table}, key, ttl) do
    Table.transaction(fn ->
      case Table.read(table, key) do
        {:ok, {_, _, value, touched, _}} ->
          Table.write(table, key, value, touched, ttl)

        {:error, :not_found} ->
          false
      end
    end)
  end

  @impl Nebulex.Adapter.Entry
  def touch(%{table: table}, key) do
    Table.transaction(fn ->
      case Table.read(table, key) do
        {:ok, {_, _, value, _, ttl}} ->
          Table.write(table, key, value, Utils.now(), ttl)

        {:error, :not_found} ->
          false
      end
    end)
  end

  ## Nebulex.Adapter.Queryable

  @impl Nebulex.Adapter.Queryable
  def execute(%{table: table}, :all, query, _opts) do
    Table.transaction(fn ->
      Table.select(table, query)
    end)
  end

  @impl Nebulex.Adapter.Queryable
  def execute(%{table: table}, :delete_all, query, _opts) do
    Table.transaction(fn ->
      Table.select(table, query)
      |> Enum.count(fn entry ->
        :ok == Table.delete(table, Entry.key(entry))
      end)
    end)
  end

  @impl Nebulex.Adapter.Queryable
  def execute(adapter_meta, :count_all, query, opts) do
    execute(adapter_meta, :all, query, opts) |> length()
  end

  @impl Nebulex.Adapter.Queryable
  def stream(%{table: table}, query, opts) do
    batch = Keyword.get(opts, :batch, 50)
    Table.stream(table, query, batch)
  end

  defp delete_and_return(table, key, return) do
    :ok = Table.delete(table, key)
    return
  end
end
