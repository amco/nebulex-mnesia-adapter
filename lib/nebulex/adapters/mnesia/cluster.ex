defmodule Nebulex.Adapters.Mnesia.Cluster do
  @moduledoc """
  This module manages Mnesia cluster nodes and table copies.
  It monitors node up and down events to ensure that table copies are
  added or removed as needed.
  """

  use GenServer

  @default_table :mnesia_cache
  @table_attrs ~w[key value touched ttl]a

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    :mnesia.start()
    :net_kernel.monitor_nodes(true)
    table = Keyword.get(opts, :table, @default_table)
    master = Keyword.get(opts, :master_node, false)
    if master, do: create_schema_and_table(table)
    {:ok, %{table: table, master: master}}
  end

  def handle_info({:nodeup, _node}, %{table: table, master: master} = state) do
    if !master, do: add_table_copy(table)
    {:noreply, state}
  end

  def handle_info({:nodedown, _node}, state) do
    {:noreply, state}
  end

  defp create_schema_and_table(table) do
    :mnesia.stop()
    :mnesia.create_schema([node()])
    :mnesia.start()
    create_table(table)
  end

  defp create_table(table) do
    :mnesia.create_table(table,
      attributes: @table_attrs,
      disc_copies: [node()]
    )
  end

  defp add_table_copy(table) do
    :mnesia.change_config(:extra_db_nodes, Node.list())
    :mnesia.add_table_copy(table, node(), :disc_copies)
  end
end
