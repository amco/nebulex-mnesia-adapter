defmodule NebulexMnesiaAdapter do
  alias :mnesia, as: Mnesia

  @attrs ~w[key value touched ttl]a

  @behaviour Nebulex.Adapter
  @behaviour Nebulex.Adapter.Queryable
  @behaviour Nebulex.Adapter.Entry

  @impl Nebulex.Adapter
  defmacro __before_compile__(_env), do: :ok

  @impl Nebulex.Adapter
  def init(_opts) do
    child_spec = Supervisor.child_spec({Agent, fn -> :ok end}, id: {Agent, 1})
    init_mnesia()
    {:ok, child_spec, %{}}
  end

  defp init_mnesia do
    Mnesia.create_schema(Node.list())
    Mnesia.start()

    Mnesia.create_table(MnesiaCache, attributes: @attrs)
  end

  @impl Nebulex.Adapter.Entry
  def get(_adapder_meta, key, _opts) do
    fn -> Mnesia.read(MnesiaCache, key) end
    |> Mnesia.transaction()
    |> case do
      {:atomic, []} ->
        nil

      {:atomic, [record]} ->
        {_table, _key, value, _touched, _ttl} = record
        value
    end
  end

  @impl Nebulex.Adapter.Entry
  def get_all(_adapder_meta, keys, _opts) do
    for(
      key <- keys,
      do:
        fn -> Mnesia.read(MnesiaCache, key) end
        |> Mnesia.transaction()
    )
    |> Enum.map(fn {:atomic, record} ->
      case record do
        [] -> nil
        [{_table, key, value, _touched, _ttl}] -> {key, value}
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
    fn -> Mnesia.write({MnesiaCache, key, value, now(), ttl}) end
    |> Mnesia.transaction()
    |> Kernel.==({:atomic, :ok})
  end

  @impl Nebulex.Adapter.Entry
  def put_all(adapter_meta, entries, ttl, :put_new, opts) do
    case get_all(adapter_meta, Map.keys(entries), opts) do
      records when records == %{} ->
        for {key, value} <- entries,
            do:
              fn -> Mnesia.write({MnesiaCache, key, value, now(), ttl}) end
              |> Mnesia.transaction()

      _other ->
        false
    end
  end

  @impl Nebulex.Adapter.Entry
  def put_all(_adapter_meta, entries, ttl, _on_write, _opts) do
    for {key, value} <- entries,
        do:
          fn -> Mnesia.write({MnesiaCache, key, value, now(), ttl}) end
          |> Mnesia.transaction()
  end

  @impl Nebulex.Adapter.Entry
  def delete(_adapter_meta, key, _opt) do
    fn -> Mnesia.delete({MnesiaCache, key}) end
    |> Mnesia.transaction()
    |> case do
      {:atomic, :ok} ->
        :ok

      {_, error} ->
        {:error, error}
    end
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
  def has_key?(_adapter_meta, key) do
    Mnesia.dirty_read(MnesiaCache, key) != []
  end

  @impl Nebulex.Adapter.Entry
  def update_counter(_adapter_meta, key, amount, ttl, default, _opts) do
    count =
      case Mnesia.dirty_read(MnesiaCache, key) do
        [] ->
          if default, do: default + amount, else: amount

        [{_table, ^key, value, _touched, _ttl}] ->
          value + amount
      end

    fn -> Mnesia.write({MnesiaCache, key, count, now(), ttl}) end
    |> Mnesia.transaction()
    |> case do
      {:atomic, :ok} -> count
      _other -> {:error, :counter_error}
    end
  end

  @impl Nebulex.Adapter.Entry
  def ttl(_adapter_meta, key) do
    Mnesia.read(MnesiaCache, key, [])
    |> Mnesia.transaction()
    |> case do
      {:atomic, {_table, _key, _value, _touched, ttl}} ->
        ttl

      _other ->
        nil
    end
  end

  @impl Nebulex.Adapter.Entry
  def touch(adapter_meta, key) do
    value = get(adapter_meta, key, [])
    ttl = ttl(adapter_meta, key)

    Mnesia.write({MnesiaCache, key, value, now(), ttl})
    |> Mnesia.transaction()
    |> case do
      {:atomic, _} ->
        true

      _other ->
        false
    end
  end

  @impl Nebulex.Adapter.Entry
  def expire(adapter_meta, key, ttl) do
    value = get(adapter_meta, key, [])

    Mnesia.write({MnesiaCache, key, value, now(), ttl})
    |> Mnesia.transaction()
    |> case do
      {:atomic, _} ->
        true

      _other ->
        false
    end
  end

  @impl Nebulex.Adapter.Queryable
  def execute(_adapter_meta, :all, nil, _opts) do
    {:atomic, records} =
      fn -> Mnesia.match_object({MnesiaCache, :_, :_, :_, :_}) end |> Mnesia.transaction()

    records
    |> Enum.map(fn {_table, _key, value, _touched, _ttl} -> value end)
  end

  @impl Nebulex.Adapter.Queryable
  def execute(_adapter_meta, :delete_all, _query, _opts) do
    {:atomic, deleted} = fn -> Mnesia.all_keys(MnesiaCache) end |> Mnesia.transaction()
    Mnesia.clear_table(MnesiaCache)
    length(deleted)
  end

  @impl Nebulex.Adapter.Queryable
  def execute(_adapter_meta, :count_all, nil, _opts) do
    {:atomic, all_keys} = fn -> Mnesia.all_keys(MnesiaCache) end |> Mnesia.transaction()

    length(all_keys)
  end

  @impl Nebulex.Adapter.Queryable
  def stream(adapter_meta, nil, opts) do
    Stream.resource(
      fn -> [] end,
      fn results ->
        case results do
          [] ->
            {:atomic, next_key} = fn -> Mnesia.first(MnesiaCache) end |> Mnesia.transaction()

            if next_key == :"$end_of_table" do
              {:halt, []}
            else
              acc =
                case opts[:return] do
                  :value ->
                    [get(adapter_meta, next_key, opts)]

                  {:key, :value} ->
                    [{next_key, get(adapter_meta, next_key, opts)}]

                  _else ->
                    [next_key]
                end

              {acc, [next_key]}
            end

          keys ->
            prev_key = List.last(keys)

            {:atomic, next_key} =
              fn -> Mnesia.next(MnesiaCache, prev_key) end |> Mnesia.transaction()

            if next_key == :"$end_of_table" do
              {:halt, []}
            else
              item = get(adapter_meta, next_key, opts)
              new_keys = List.insert_at(keys, -1, next_key)

              acc =
                case opts[:return] do
                  :value ->
                    [item]

                  {:key, :value} ->
                    [{next_key, item}]

                  _else ->
                    [next_key]
                end

              {acc, new_keys}
            end
        end
      end,
      & &1
    )
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
end
