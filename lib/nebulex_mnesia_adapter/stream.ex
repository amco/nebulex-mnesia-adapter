defmodule NebulexMnesiaAdapter.Stream do
  @moduledoc """
  Provides a stream abstraction over a Mnesia-backed Nebulex cache table.

  This module enables streaming over the keys stored in the cache using
  Elixir's `Stream.resource/3`, allowing for lazy evaluation and efficient
  traversal of cache entries.

  ## Features

    * Starts a stream that lazily reads keys from the Mnesia table.
    * Traverses the table using the `:mnesia` `first/1` and `next/2` operations.
    * Supports customizable return formats via the `:return` option:
      * `:value` – returns only the cached values.
      * `{:key, :value}` – returns key-value tuples.
      * Any other value (or no option) – returns keys only.
  """

  alias NebulexMnesiaAdapter.Table

  def call(opts) do
    Stream.resource(
      fn -> [] end,
      fn results ->
        case results do
          [] ->
            {:atomic, next_key} = Table.first()
            next(next_key, [next_key], opts)
          keys ->
            {:atomic, next_key} =
              List.last(keys)
              |> Table.next()

            new_keys = List.insert_at(keys, -1, next_key)
            next(next_key, new_keys, opts)
        end
      end,
      & &1
    )
  end

  defp next(:"$end_of_table", _acc, _opts) do
    {:halt, []}
  end

  defp next(key, acc, opts) do
    {next_value(key, opts), acc}
  end

  defp next_value(key, opts) do
    case opts[:return] do
      :value ->
        [fetch_value(key)]

      {:key, :value} ->
        [{key, fetch_value(key)}]

      _else ->
        [key]
    end
  end

  defp fetch_value(key) do
    Table.read(key)
    |> case do
      {_table, _key, value, _touched, _ttl} ->
        value

      _other ->
        nil
    end
  end
end
