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

      iex> query = [{:==, :"$1", :key1}]
      iex> Nebulex.Adapters.Mnesia.Table.Stream.select(:table, query, 2) |> Enum.to_list()
      [{:table, :key1, "value1", 1759420681791, :infinity}]

  """
  @spec select(atom, list, non_neg_integer) :: Enumerable.t()
  def select(_table, _query, _batch) do
  end
end
