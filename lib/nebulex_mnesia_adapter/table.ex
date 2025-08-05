defmodule NebulexMnesiaAdapter.Table do
  @moduledoc """
  Provides a lightweight abstraction over an Mnesia table used as a simple key-value store.

  This module manages a single Mnesia table with the following attributes:

    * `key` - the identifier for the record (primary key)
    * `value` - the value stored for the key
    * `touched` - a timestamp or versioning value (optional usage)
    * `ttl` - time-to-live metadata for expiry logic (optional usage)

  ### Features

  - Initializes the Mnesia schema and creates the table
  - Supports basic operations like read, write, delete
  - Provides utilities to list all records or keys
  - Wraps all operations in `:mnesia.transaction/1` for atomicity and consistency
  """

  alias :mnesia, as: Mnesia

  @attrs ~w[key value touched ttl]a
  @default_table MnesiaCache

  def setup do
    Mnesia.create_schema(Node.list())
    Mnesia.start()

    Mnesia.create_table(MnesiaCache, attributes: @attrs)
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

      _else ->
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
