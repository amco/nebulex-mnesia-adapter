defmodule Nebulex.Adapters.Mnesia.Cluster do
  @moduledoc """
  This module manages Mnesia cluster nodes and table copies.
  It monitors node up and down events to ensure that table copies are
  added or removed as needed.
  """

  use GenServer

  alias :mnesia, as: Mnesia

  @table_attrs ~w[key value touched ttl]a

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    Mnesia.start()
    :net_kernel.monitor_nodes(true)
    cache = Keyword.fetch!(opts, :cache)
    table = Keyword.get(opts, :table, cache)
    master = Keyword.get(opts, :master_node, false)
    if master, do: create_schema_and_table(table)
    {:ok, %{table: table, master: master}}
  end

  def handle_info({:nodeup, _node}, %{table: table, master: master} = state) do
    unless master, do: add_table_copy(table)
    {:noreply, state}
  end

  def handle_info({:nodedown, _node}, state) do
    {:noreply, state}
  end

  defp create_schema_and_table(table) do
    Mnesia.stop()
    Mnesia.create_schema([Node.self()])
    Mnesia.start()
    create_table(table)
  end

  defp create_table(table) do
    Mnesia.create_table(table,
      attributes: @table_attrs,
      disc_copies: [Node.self()]
    )
  end

  defp add_table_copy(table) do
    Mnesia.change_config(:extra_db_nodes, Node.list())
    Mnesia.add_table_copy(table, Node.self(), :disc_copies)
  end
end
