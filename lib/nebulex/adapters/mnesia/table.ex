defmodule Nebulex.Adapters.Mnesia.Table do
  @moduledoc """
  This module provides basic operations for interacting with Mnesia tables.
  """

  alias __MODULE__.Stream
  alias :mnesia, as: Mnesia

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
    case Mnesia.read({table, key}) do
      [entry] -> {:ok, entry}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Retrieves the first key from the specified Mnesia table.

  ## Parameters

    - `table`: The name of the Mnesia table (atom).

  ## Returns

    - `{:ok, key}`: If the table has entries and the first key is found.
    - `{:error, :not_found}`: If the table is empty.

  ## Examples

      iex> Nebulex.Adapters.Mnesia.Table.first(:table)
      {:ok, :first_key}

      iex> Nebulex.Adapters.Mnesia.Table.first(:empty_table)
      {:error, :not_found}

  """
  @spec first(atom) :: {:ok, term} | {:error, :not_found}
  def first(table) do
    case Mnesia.first(table) do
      :"$end_of_table" -> {:error, :not_found}
      key -> {:ok, key}
    end
  end

  @doc """
  Retrieves the next key in the specified Mnesia table after the given key.

  ## Parameters

    - `table`: The name of the Mnesia table (atom).
    - `key`: The current key (term).

  ## Returns

    - `{:ok, next_key}`: If the next key is found.
    - `{:error, :not_found}`: If there is no next key (end of table).

  ## Examples

      iex> Nebulex.Adapters.Mnesia.Table.next(:table, :current_key)
      {:ok, :next_key}

      iex> Nebulex.Adapters.Mnesia.Table.next(:table, :last_key)
      {:error, :not_found}

  """
  @spec next(atom, term) :: {:ok, term} | {:error, :not_found}
  def next(table, key) do
    case Mnesia.next(table, key) do
      :"$end_of_table" -> {:error, :not_found}
      next_key -> {:ok, next_key}
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
    Mnesia.write({table, key, value, touched, ttl})
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
    Mnesia.delete({table, key})
  end

  @doc """
  Selects entries from the specified Mnesia table based on given options.

  ## Parameters

    - `table`: The name of the Mnesia table (atom).
    - `opts`: A keyword list of options.
      - `:guards` - A list of guard conditions (default: `[]`).
      - `:return` - A list specifying which attributes to return (default: `[:"$1"]`).

  ## Returns

    - A list of selected entries.

  ## Examples

      iex> guards = [:"$2" > 10]
      iex> return = [:"$1", :"$2"]
      iex> Nebulex.Adapters.Mnesia.Table.select(:table, guards: guards, return: return)
      [{:key1, 15}, {:key2, 20}]

      iex> Nebulex.Adapters.Mnesia.Table.select(:table)
      [:key1, :key2, :key3]

  """
  @spec select(atom, keyword) :: [term]
  def select(table, opts \\ []) do
    guards = Keyword.get(opts, :guards, [])
    return = Keyword.get(opts, :return, [:"$1"])
    attrs = {table, :"$1", :"$2", :"$3", :"$4"}
    Mnesia.select(table, [{attrs, guards, return}])
  end

  @doc """
  Streams entries from the specified Mnesia table based on given options.

  ## Parameters

    - `table`: The name of the Mnesia table (atom).
    - `opts`: A keyword list of options (same as in `select/2`).

  ## Returns

    - A stream of selected entries.

  ## Examples

      iex> opts = [return: :key]
      iex> Nebulex.Adapters.Mnesia.Table.stream(:table, opts) |> Enum.to_list()
      [:key1, :key2, :key3]

      iex> opts = [return: :value]
      iex> Nebulex.Adapters.Mnesia.Table.stream(:table, opts) |> Enum.to_list()
      [value1, value2, value3]

      iex> opts = [return: {:key, :value}]
      iex> Nebulex.Adapters.Mnesia.Table.stream(:table, opts) |> Enum.to_list()
      [{:key1, value1}, {:key2, value2}, {:key3, value3}]

  """
  @spec stream(atom, keyword) :: Enumerable.t()
  def stream(table, opts), do: Stream.select(table, opts)

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

      iex> Nebulex.Adapters.Mnesia.Table.transaction(fn -> Mnesia.abort(:some_reason) end)
      {:error, :some_reason}

  """
  @spec transaction((-> any)) :: any | {:error, term}
  def transaction(fun) do
    case Mnesia.transaction(fun) do
      {:atomic, result} -> result
      {:aborted, reason} -> {:error, reason}
    end
  end
end
