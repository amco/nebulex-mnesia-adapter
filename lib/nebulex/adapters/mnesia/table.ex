defmodule Nebulex.Adapters.Mnesia.Table do
  @moduledoc """
  This module provides basic operations for interacting with Mnesia tables.
  """

  alias __MODULE__.Stream

  @doc """
  Reads an entry from the specified Mnesia table by key.

  ## Parameters

    - `table`: The name of the Mnesia table (atom).
    - `key`: The key to look up (term).

  ## Returns

    - `{:ok, entry}`: If the entry is found.
    - `{:error, :not_found}`: If the entry is not found.

  ## Examples

      iex> Nebulex.Adapters.Mnesia.Table.read(:table, :key)
      {:ok, {:table, :key, "value", 1759420681791, :infinity}}

      iex> Nebulex.Adapters.Mnesia.Table.read(:table, :unknown_key)
      {:error, :not_found}

  """
  @spec read(atom, term) :: {:ok, tuple} | {:error, :not_found}
  def read(table, key) do
    case :mnesia.read({table, key}) do
      [entry] -> {:ok, entry}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Writes a key-value pair to the specified Mnesia table.

  ## Parameters

    - `table`: The name of the Mnesia table (atom).
    - `key`: The key to write (term).
    - `value`: The value to write (term).
    - `touched`: The timestamp when the entry was last touched (integer).
    - `ttl`: The time-to-live for the entry (term or integer).

  ## Returns

    - `:ok`: If the write operation is successful.

  ## Examples

      iex> Nebulex.Adapters.Mnesia.Table.write(:table, :key, "value", 1759420681791, :infinity)
      :ok

  """
  @spec write(atom, term, term, integer, term | integer) :: :ok
  def write(table, key, value, touched, ttl) do
    :mnesia.write({table, key, value, touched, ttl})
  end

  @doc """
  Deletes an entry from the specified Mnesia table by key.

  ## Parameters

    - `table`: The name of the Mnesia table (atom).
    - `key`: The key to delete (term).

  ## Returns

    - `:ok`: If the delete operation is successful.

  ## Examples

      iex> Nebulex.Adapters.Mnesia.Table.delete(:table, :key)
      :ok

  """
  @spec delete(atom, term) :: :ok
  def delete(table, key) do
    :mnesia.delete({table, key})
  end

  @doc """
  Selects entries from the specified Mnesia table based on a query.

  ## Parameters

    - `table`: The name of the Mnesia table (atom).
    - `query`: The selection query (tuple or nil).

  ## Returns

    - A list of matching entries (list of tuples).

  ## Examples

      iex> Nebulex.Adapters.Mnesia.Table.select(:table)
      [{:table, :key, "value", 1759420681791, :infinity}]

      iex> Nebulex.Adapters.Mnesia.Table.select(:table, [:"$1 == :key1"])
      [{:table, :key, "value", 1759420681791, :infinity}]

  """
  @spec select(atom, tuple | nil) :: [tuple]
  def select(table, nil), do: select(table, [])

  def select(table, query) do
    :mnesia.select(table, [{{table, :"$1", :"$2", :"$3", :"$4"}, query, [:"$_"]}])
  end

  @doc """
  Streams entries from the specified Mnesia table in batches.

  ## Parameters

    - `table`: The name of the Mnesia table (atom).
    - `query`: The selection query (tuple or nil).
    - `batch`: The batch size for streaming (non-negative integer).

  ## Returns

    - An enumerable stream of matching entries.

  ## Examples

      iex> Nebulex.Adapters.Mnesia.Table.stream(:table, 2) |> Enum.to_list()
      [{:table, :key1, "value1", 1759420681791, :infinity}]

      iex> Nebulex.Adapters.Mnesia.Table.stream(:table, [:"$1 == :key1"], 2) |> Enum.to_list()
      [{:table, :key1, "value1", 1759420681791, :infinity}]

  """
  @spec stream(atom, tuple | nil, non_neg_integer) :: Enumerable.t()
  def stream(table, nil, batch), do: stream(table, [], batch)
  def stream(table, query, batch), do: Stream.select(table, query, batch)

  @doc """
  Wraps a function in a Mnesia transaction.

  ## Parameters

    - `fun`: The function to execute within the transaction (arity 0).

  ## Returns

    - The result of the function if the transaction is successful.
    - `{:error, reason}` if the transaction is aborted.

  ## Examples

      iex> Nebulex.Adapters.Mnesia.Table.transaction(fn -> :ok end)
      :ok

      iex> Nebulex.Adapters.Mnesia.Table.transaction(fn -> :mnesia.abort(:some_reason) end)
      {:error, :some_reason}

  """
  @spec transaction((() -> any)) :: any | {:error, term}
  def transaction(fun) do
    case :mnesia.transaction(fun) do
      {:atomic, result} -> result
      {:aborted, reason} -> {:error, reason}
    end
  end
end
