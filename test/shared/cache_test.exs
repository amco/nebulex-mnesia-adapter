defmodule NebulexMnesiaAdapter.CacheTest do
  @moduledoc """
  Shared Tests
  """

  defmacro __using__(_opts) do
    quote do
      use Nebulex.Cache.EntryTest
      use Nebulex.Cache.EntryPropTest
      use Nebulex.Cache.QueryableTest
      use Nebulex.Cache.EntryExpirationTest
    end
  end
end
