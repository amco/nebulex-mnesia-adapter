defmodule Nebulex.Adapters.Mnesia.Entry do
  @moduledoc """
  This module defines a struct that represents a cache entry in the Mnesia
  adapter for Nebulex. It includes fields for the table name, key, value,
  last touched timestamp, and time-to-live (TTL) information.
  """

  alias Nebulex.Adapters.Mnesia.Utils

  @type t :: {
          table :: atom(),
          key :: any(),
          value :: any(),
          touched :: integer(),
          ttl :: non_neg_integer() | :infinity
        }

  @doc """
  Returns the key of the cache entry.

  ## Parameters

    - entry: A tuple representing the cache entry.

  ## Examples

      iex> entry = {:table, :key, "value", 1759420681791, 3600}
      iex> Nebulex.Adapters.Mnesia.Entry.key(entry)
      :key

  """
  @spec key(entry :: t()) :: any()
  def key({_table, key, _value, _touched, _ttl}), do: key

  @doc """
  Returns the value of the cache entry.

  ## Parameters

    - entry: A tuple representing the cache entry.

  ## Examples

      iex> entry = {:table, :key, "value", 1759420681791, 3600}
      iex> Nebulex.Adapters.Mnesia.Entry.value(entry)
      "value"

  """
  @spec value(entry :: t()) :: any()
  def value({_table, _key, value, _touched, _ttl}), do: value

  @doc """
  Returns the TTL (time-to-live) of the cache entry.

  ## Parameters

    - entry: A tuple representing the cache entry.

  ## Examples

      iex> entry = {:table, :key, "value", 1759420681791, 3600}
      iex> Nebulex.Adapters.Mnesia.Entry.ttl(entry)
      3600

  """
  @spec ttl(entry :: t()) :: non_neg_integer() | :infinity
  def ttl({_table, _key, _value, _touched, ttl}), do: ttl

  @doc """
  Returns the remaining TTL of the cache entry.

  ## Parameters

    - entry: A tuple representing the cache entry.

  ## Returns

    - The remaining TTL in seconds, or `:infinity` if the TTL is infinite.
    - Calculates remaining TTL as `ttl - (current_time - touched)`.

  ## Examples

      iex> entry = {:table, :key, "value", 1759420681791, 3600}
      iex> Nebulex.Adapters.Mnesia.Entry.remaining_ttl(entry)
      3595 # (assuming 5 seconds have passed since touched time)

      iex> entry = {:table, :key, "value", 1759420681791, :infinity}
      iex> Nebulex.Adapters.Mnesia.Entry.remaining_ttl(entry)
      :infinity

  """
  @spec remaining_ttl(entry :: t()) :: integer() | :infinity
  def remaining_ttl({_table, _key, _value, touched, ttl}) do
    case ttl do
      :infinity -> :infinity
      _ -> ttl - (Utils.now() - touched)
    end
  end

  @doc """
  Returns the status of the cache entry.

  ## Parameters

    - entry: A tuple representing the cache entry.

  ## Returns

    - `{:ok, :active}` if the entry is valid.
    - `{:error, :expired}` if the entry has expired.

  ## Examples

      iex> entry = {:table, :key, "value", 1759420681791, 3600}
      iex> Nebulex.Adapters.Mnesia.Entry.status(entry)
      {:ok, :active}

      iex> entry = {:table, :key, "value", 1759420681791, 1}
      iex> :timer.sleep(2000) # wait for 2 seconds
      iex> Nebulex.Adapters.Mnesia.Entry.status(entry)
      {:error, :expired}

  """
  @spec status(entry :: t()) :: {:ok, :active} | {:error, :expired}
  def status(entry) do
    case remaining_ttl(entry) do
      :infinity -> {:ok, :active}
      remaining when remaining > 0 -> {:ok, :active}
      _ -> {:error, :expired}
    end
  end
end
