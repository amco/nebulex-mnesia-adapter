# Nebulex Mnesia Adapter

Nebulex adapter using Mnesia as storage.

## Installation

Add `nebulex_mnesia_adapter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nebulex_mnesia_adapter, "~> 2.6.5"}
  ]
end
```

## Usage

Create the cache module as the following example:

```elixir
defmodule MyApp.Cache do
  use Nebulex.Cache,
    otp_app: :my_app,
    adapter: Nebulex.Adapters.Mnesia
end
```

## Configuration

You can configure the cache in your `config/config.exs` file. For example:

```elixir
config :my_app, MyApp.Cache,
  table: :other_table_name, # (default: MyApp.Cache)
  cleanup_interval: :timer.hours(2) # 2 hours (default: 6 hours)
```

It is also recommended to set the mnesia directory for disc copies on `config/config.exs`

```elixir
config :mnesia, dir: ~c"/path/to/my/db/folder"
```

If you are pushing this to an environment ensure the folder is created ahead of time,
Mnesia will not create the folder for you.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/nebulex_mnesia_adapter>.
