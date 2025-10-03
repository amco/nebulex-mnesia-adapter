defmodule Nebulex.Adapters.Mnesia.Utils do
  @moduledoc """
  This module provides utility functions for the Nebulex Mnesia adapter.
  """

  @doc """
  Returns the current system time in milliseconds.

  ## Examples

      iex> Nebulex.Adapters.Mnesia.Utils.now()
      1759420681791

  """
  @spec now() :: integer()
  def now, do: :os.system_time(:millisecond)
end
