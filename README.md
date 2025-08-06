# NebulexMnesiaAdapter

**Nebulex adapter using Mnesia as storage**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `nebulex_mnesia_adapter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nebulex_mnesia_adapter, "~> 0.1.0"}
  ]
end
```

Add the table configuration GenServer on the application module `lib/my_app/application.ex`

```elixir
children =
  [
    ...
    {Nebulex.Adapters.Mnesia.Table, nodes: [Node.self()]}
    ...
  ]

Supervisor.start_link(childre, opts)
```

It is recommended to set the mnesia directory for disc copies on `config/config.exs`

```elixir
config :mnesia, dir: ~c"/path/to/my/db/folder"
```

If you are pushing this to an environment ensure the folder is created ahead of time,
Mnesia will not create the folder for you


Finally configure your cache module with Nebulex

```elixir
defmodule MyApp.Cache do
  use Nebulex.Cache,
    otp_app: :my_app,
    adapter: Nebulex.Adapters.Mnesia
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/nebulex_mnesia_adapter>.

