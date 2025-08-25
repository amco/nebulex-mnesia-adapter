defmodule Nebulex.Adapters.Mnesia.Table do
  @moduledoc """
  Provides a lightweight abstraction over an Mnesia table used as a simple key-value store.

  This module manages a single Mnesia table with the following attributes:

    * `key` - the identifier for the record (primary key)
    * `value` - the value stored for the key
    * `touched` - a timestamp or versioning value (optional usage)
    * `ttl` - time-to-live metadata for expiry logic (optional usage)

  """

  alias :mnesia, as: Mnesia

  @attrs ~w[key value touched ttl]a

  # TODO: find a way to make this configurable
  @default_table MnesiaCache

  def create_table(nodes) do
    case Mnesia.create_table(cache_table(), attributes: @attrs, disc_copies: nodes) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, _}} -> :ok
      other -> IO.puts(inspect(other), label: "Table creation error")
    end
  end

  def copy_table(node) do
    case :rpc.call(node, Mnesia, :start, []) do
      :ok ->
        IO.puts("Mnesia started on #{inspect(node)}. Adding table copy...")
        :mnesia.add_table_copy(cache_table(), node, :disc_copies)

      other ->
        IO.puts(inspect(other), label: "Failed to start Mnesia on new node")
    end
  end

  def delete_table_copy(node) do
    Mnesia.del_table_copy(cache_table(), node)
  end

  def bulk_read(keys) when is_list(keys) do
    fn -> for key <- keys, do: Mnesia.read(cache_table(), key) end
    |> Mnesia.transaction()
    |> case do
      {:atomic, []} ->
        []

      {:atomic, results} ->
        results
        |> Enum.filter(&(&1 != []))
        |> Enum.map(fn [record] -> record end)

      _other ->
        []
    end
  end

  def read(key) do
    fn -> Mnesia.read(cache_table(), key) end
    |> Mnesia.transaction()
    |> case do
      {:atomic, []} ->
        nil

      {:atomic, [response]} ->
        response

      error ->
        {:error, error}
    end
  end

  def bulk_write(values) when is_list(values) do
    fn ->
      Enum.map(values, &Tuple.insert_at(&1, 0, cache_table()))
      |> Enum.map(&Mnesia.write/1)
    end
    |> Mnesia.transaction()
    |> case do
      {:atomic, response} -> response
      error -> {:error, error}
    end
  end

  def write(value) do
    tab_key = Tuple.insert_at(value, 0, cache_table())

    fn -> Mnesia.write(tab_key) end
    |> Mnesia.transaction()
    |> case do
      {:atomic, :ok} -> :ok
      other -> other
    end
  end

  def delete(key) do
    fn -> Mnesia.delete({cache_table(), key}) end
    |> Mnesia.transaction()
    |> case do
      {:atomic, :ok} ->
        :ok

      {_, error} ->
        {:error, error}
    end
  end

  def all_records do
    fn -> Mnesia.match_object({cache_table(), :_, :_, :_, :_}) end
    |> Mnesia.transaction()
    |> case do
      {:atomic, records} ->
        records

      _error ->
        {:error, :unexpected}
    end
  end

  def clear! do
    all_keys()
    |> tap(fn _ -> Mnesia.clear_table(cache_table()) end)
  end

  def all_keys do
    fn -> Mnesia.all_keys(MnesiaCache) end
    |> Mnesia.transaction()
    |> case do
      {:atomic, keys} -> keys
      _other -> {:error, :unexpected_deleted}
    end
  end

  def first do
    fn -> Mnesia.first(cache_table()) end
    |> Mnesia.transaction()
  end

  def next(key) do
    fn -> Mnesia.next(cache_table(), key) end
    |> Mnesia.transaction()
  end

  defp cache_table do
    @default_table
  end
end
