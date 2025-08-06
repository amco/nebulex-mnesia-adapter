defmodule NebulexMnesiaAdapter.MixProject do
  use Mix.Project

  @nbx_vsn "2.6.5"

  def project do
    [
      app: :nebulex_mnesia_adapter,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      nebulex_dep(),
      {:stream_data, "~> 1.1", only: [:dev, :test]},
      {:telemetry, "~> 0.4 or ~> 1.0", optional: true}
    ]
  end

  defp nebulex_dep do
    if path = System.get_env("NEBULEX_PATH") do
      {:nebulex, "~> #{@nbx_vsn}", path: path}
    else
      {:nebulex, "~> #{@nbx_vsn}"}
    end
  end

  defp aliases do
    [
      "nbx.setup": [
        "cmd rm -rf nebulex",
        "cmd git clone --depth 1 --branch v#{@nbx_vsn} https://github.com/elixir-nebulex/nebulex"
      ]
    ]
  end
end
