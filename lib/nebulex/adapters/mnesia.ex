defmodule Nebulex.Adapters.Mnesia do
  alias __MODULE__.Table

  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.Queryable
  @behaviour Nebulex.Adapter.Entry

  @impl Nebulex.Adapter
  defmacro __before_compile__(_env), do: :ok

  @impl Nebulex.Adapter
  def init(_opts) do
    child_spec = Supervisor.child_spec({Agent, fn -> :ok end}, id: {Agent, 1})

    check_cluster()

    {:ok, child_spec, %{}}
  end

  def check_cluster do
    nodes = Node.list() ++ [Node.self()]
    IO.puts("Setting up Mnesia schema on nodes: #{inspect(nodes)}")

    :mnesia.create_schema(nodes)
    :ok = :mnesia.start()

    Table.create_table(nodes)
  end

  @impl Nebulex.Adapter.Entry
  def get(_adapder_meta, key, _opts) do
    Table.read(key)
    |> case do
      {_table, _key, _value, _touched, _ttl} = record ->
        handle_expired(record)

      _other ->
        nil
    end
  end

  defp handle_expired({_, _, value, _touched, :infinity}), do: value

  defp handle_expired({_, key, value, touched, ttl}) do
    with true <- expired?(touched, ttl),
         :ok <- Table.delete(key) do
      nil
    else
      _ -> value
    end
  end

  @impl Nebulex.Adapter.Entry
  def get_all(_adapder_meta, keys, _opts) do
    Table.bulk_read(keys)
    |> Enum.map(fn record ->
      case record do
        {_table, key, value, _touched, _ttl} -> {key, value}
        _other -> nil
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.into(%{})
  end

  @impl Nebulex.Adapter.Entry
  def put(_adapter_meta, key, value, ttl, on_write, opts)

  def put(adapter_meta, key, value, ttl, :put_new, opts) do
    case get(adapter_meta, key, opts) do
      nil ->
        put(adapter_meta, key, value, ttl, :put, opts)

      _other ->
        false
    end
  end

  @impl Nebulex.Adapter.Entry
  def put(adapter_meta, key, value, ttl, :replace, opts) do
    case get(adapter_meta, key, opts) do
      nil ->
        false

      _other ->
        put(adapter_meta, key, value, ttl, :put, opts)
    end
  end

  @impl Nebulex.Adapter.Entry
  def put(_adapter_meta, key, value, ttl, _on_write, _opts) do
    Table.write({key, value, now(), ttl})
    |> Kernel.==(:ok)
  end

  @impl Nebulex.Adapter.Entry
  def put_all(adapter_meta, entries, ttl, :put_new, opts) do
    case get_all(adapter_meta, Map.keys(entries), opts) do
      records when records == %{} ->
        for({key, value} <- entries, do: {key, value, now(), ttl})
        |> Table.bulk_write()

      _other ->
        false
    end
  end

  @impl Nebulex.Adapter.Entry
  def put_all(_adapter_meta, entries, ttl, _on_write, _opts) do
    for {key, value} <- entries,
        do: Table.write({key, value, now(), ttl})
  end

  @impl Nebulex.Adapter.Entry
  def delete(_adapter_meta, key, _opt) do
    Table.delete(key)
  end

  @impl Nebulex.Adapter.Entry
  def take(adapter_meta, key, opt) do
    case get(adapter_meta, key, opt) do
      nil ->
        nil

      obj ->
        delete(adapter_meta, key, opt)
        obj
    end
  end

  @impl Nebulex.Adapter.Entry
  def has_key?(adapter_meta, key) do
    !!get(adapter_meta, key, [])
  end

  @impl Nebulex.Adapter.Entry
  def update_counter(_adapter_meta, key, amount, ttl, default, _opts) do
    count =
      case Table.read(key) do
        nil ->
          if default, do: default + amount, else: amount

        {_table, ^key, value, touched, _stored_ttl} ->
          if expired?(touched, ttl), do: default + amount, else: value + amount
      end

    Table.write({key, count, now(), ttl})
    |> case do
      :ok -> count
      _other -> {:error, :counter_error}
    end
  end

  @impl Nebulex.Adapter.Entry
  def ttl(_adapter_meta, key) do
    Table.read(key)
    |> case do
      {_table, _key, _value, touched, ttl} ->
        remaining_time(touched, ttl)

      _other ->
        nil
    end
  end

  defp remaining_time(_touched, :infinity), do: :infinity

  defp remaining_time(touched, ttl) do
    with time_left <- touched + ttl - now(),
         true <- time_left > 0 do
      time_left
    else
      _ -> nil
    end
  end

  @impl Nebulex.Adapter.Entry
  def touch(adapter_meta, key) do
    value = get(adapter_meta, key, [])
    ttl = ttl(adapter_meta, key)

    has_key?(adapter_meta, key) &&
      Table.write({key, value, now(), ttl}) == :ok
  end

  @impl Nebulex.Adapter.Entry
  def expire(adapter_meta, key, ttl) do
    value = get(adapter_meta, key, [])

    has_key?(adapter_meta, key) &&
      Table.write({key, value, now(), ttl}) == :ok
  end

  @impl Nebulex.Adapter.Queryable
  def execute(_adapter_meta, :all, nil, _opts) do
    Table.all_records()
    |> Enum.map(fn {_table, key, _value, _touched, _ttl} -> key end)
  end

  @impl Nebulex.Adapter.Queryable
  def execute(_adapter_meta, :delete_all, _query, _opts) do
    Table.clear!() |> length()
  end

  @impl Nebulex.Adapter.Queryable
  def execute(_adapter_meta, :count_all, nil, _opts) do
    Table.all_keys()
    |> length()
  end

  @impl Nebulex.Adapter.Queryable
  def stream(_adapter_meta, nil, opts) do
    Nebulex.Adapters.Mnesia.Stream.call(opts)
  end

  @doc """
  All queries are invalid, as it is not supported by mnesia on streams
  """
  @impl Nebulex.Adapter.Queryable
  def stream(_adapter_meta, query, _opts) do
    raise Nebulex.QueryError, message: "invalid match spec", query: query
  end

  defp now do
    :os.system_time(:millisecond)
  end

  defp expired?(_touched, :infinity) do
    false
  end

  defp expired?(touched, ttl) do
    now() > touched + ttl
  end

  def create_table(nodes \\ nil) do
    nodes = unless nodes, do: [Node.self()], else: nodes

    Table.create_table(nodes)
  end

  def copy_table(node) do
    Table.copy_table(node)
  end

  def delete_table(node) do
    Table.delete_table_copy(node)
  end
end
