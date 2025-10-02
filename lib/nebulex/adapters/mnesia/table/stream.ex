defmodule Nebulex.Adapters.Mnesia.Table.Stream do
  @moduledoc """
  This module provides a stream interface for querying Mnesia tables in batches.
  """

  @doc """
  Streams the results of a Mnesia table query in batches.

  ## Parameters

    - `table`: The Mnesia table to query.
    - `query`: The query pattern to match against the table.
    - `batch`: The number of records to fetch in each batch.

  ## Returns

    - A stream of records matching the query.

  ## Example

      iex> Nebulex.Adapters.Mnesia.Table.Stream.select(:table, [], 10) |> Enum.to_list()
      [{:table, :key, "value", 1759420681791, :infinity}, ...]

  """
  @spec select(atom, list, non_neg_integer) :: Enumerable.t()
  def select(table, query, batch) do
    Stream.resource(
      fn ->
        :mnesia.transaction(fn ->
          :mnesia.select(table, [{{table, :"$1", :"$2", :"$3", :"$4"}, query, [:"$_"]}], batch, :read)
        end)
      end,
      fn
        {:atomic, {[], :'$end_of_table'}} -> {:halt, nil}
        {:atomic, {entries, cont}} -> {entries, {:cont, cont}}

        {:cont, cont} ->
          case :mnesia.transaction(fn -> :mnesia.select(cont) end) do
            {:atomic, {[], :'$end_of_table'}} -> {:halt, nil}
            {:atomic, {entries, cont}} -> {entries, {:cont, cont}}
          end
      end,
      fn _ -> :ok end
    )
  end
end
