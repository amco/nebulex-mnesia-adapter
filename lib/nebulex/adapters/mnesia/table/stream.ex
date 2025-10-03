defmodule Nebulex.Adapters.Mnesia.Table.Stream do
  @moduledoc """
  This module provides streaming capabilities for Mnesia tables.
  """

  alias Nebulex.Adapters.Mnesia.{Table, Entry}

  @doc """
  Streams entries from the specified Mnesia table.

  ## Parameters

    - `table`: The name of the Mnesia table (atom).
    - `opts`: Options for streaming (keyword list).
      - `:return` - Specifies what to return for each entry. Can be:
        - `:key` (default) - Returns only the keys.
        - `:value` - Returns only the values.
        - `{:key, :value}` - Returns both keys and values as tuples.

  ## Returns

    - A stream of entries from the table based on the specified return option.

  ## Examples

      iex> opts = [return: :key]
      iex> Nebulex.Adapters.Mnesia.Table.Stream.select(:table, opts) |> Enum.to_list()
      [:key1, :key2, :key3]

      iex> opts = [return: :value]
      iex> Nebulex.Adapters.Mnesia.Table.Stream.select(:table, opts) |> Enum.to_list()
      [value1, value2, value3]

      iex> opts = [return: {:key, :value}]
      iex> Nebulex.Adapters.Mnesia.Table.Stream.select(:table, opts) |> Enum.to_list()
      [{:key1, value1}, {:key2, value2}, {:key3, value3}]

  """
  @spec select(atom, keyword) :: Enumerable.t()
  def select(table, opts) do
    Stream.resource(
      fn -> start_entry(table) end,
      fn acc -> next(acc, table, opts) end,
      fn _acc -> :ok end
    )
  end

  defp next({:first, key}, table, opts), do: fetch_acc(table, key, opts)
  defp next({:cont, key}, table, opts), do: next_entry(table, key, opts)
  defp next({:halt, nil}, _table, _opts), do: {:halt, nil}

  defp start_entry(table) do
    Table.transaction(fn ->
      case Table.first(table) do
        {:ok, key} -> {:first, key}
        {:error, :not_found} -> {:halt, nil}
      end
    end)
  end

  defp next_entry(table, key, opts) do
    Table.transaction(fn ->
      case Table.next(table, key) do
        {:ok, key} -> fetch_acc(table, key, opts)
        {:error, :not_found} -> {:halt, nil}
      end
    end)
  end

  defp fetch_acc(table, key, opts) do
    return = Keyword.get(opts, :return, :key)
    {fetch(table, key, return), {:cont, key}}
  end

  defp fetch(_table, key, :key), do: [key]

  defp fetch(table, key, :value) do
    case fetch_entry(table, key) do
      {:ok, entry} -> [Entry.value(entry)]
      _error -> []
    end
  end

  defp fetch(table, key, {:key, :value}) do
    case fetch_entry(table, key) do
      {:ok, entry} -> [{key, Entry.value(entry)}]
      _error -> []
    end
  end

  defp fetch_entry(table, key) do
    Table.transaction(fn ->
      with {:ok, entry} <- Table.read(table, key),
           {:ok, :active} <- Entry.status(entry) do
        {:ok, entry}
      end
    end)
  end
end
