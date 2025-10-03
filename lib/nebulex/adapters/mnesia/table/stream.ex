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
    return = Keyword.get(opts, :return, :key)

    Stream.resource(
      fn ->
        :mnesia.transaction(fn ->
          :mnesia.first(table)
        end)
      end,
      fn
        {:atomic, :"$end_of_table"} ->
          {:halt, nil}

        {:atomic, key} ->
          {fetch(table, key, return), {:cont, key}}

        {:cont, key} ->
          case :mnesia.transaction(fn -> :mnesia.next(table, key) end) do
            {:atomic, :"$end_of_table"} ->
              {:halt, nil}

            {:atomic, next_key} ->
              {fetch(table, next_key, return), {:cont, next_key}}
          end

        _ ->
          {:halt, nil}
      end,
      fn _ -> :ok end
    )
  end

  defp fetch(table, key, return) do
    case return do
      :key ->
        [key]

      :value ->
        fetch_value(table, key)

      {:key, :value} ->
        case fetch_value(table, key) do
          [value] -> [{key, value}]
          [] -> []
        end
    end
  end

  defp fetch_value(table, key) do
    Table.transaction(fn ->
      with {:ok, entry} <- Table.read(table, key),
           {:ok, :active} <- Entry.status(entry) do
        [Entry.value(entry)]
      else
        {:error, :not_found} -> []
        {:error, :expired} -> []
      end
    end)
  end
end
