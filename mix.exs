defmodule NebulexMnesiaAdapter.MixProject do
  use Mix.Project

  @source_url "https://github.com/amco/nebulex-mnesia-adapter"
  @nbx_vsn "2.6.5"
  @version "0.1.0"

  def project do
    [
      app: :nebulex_mnesia_adapter,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      included_applications: [:mnesia],
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      nebulex_dep(),
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:stream_data, "~> 1.1", only: [:dev, :test]}
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

  defp docs do
    [
      main: "readme",
      formatters: ["html"],
      extras: ["CHANGELOG.md", "CONTRIBUTING.md", "README.md"]
    ]
  end

  defp package do
    [
      description: "Nebulex adapter for Mnesia",
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "CONTRIBUTING.md", "LICENSE"],
      maintainers: ["Javier Guerra", "Alejandro Gutiérrez"],
      licenses: ["MIT"],
      links: %{
        GitHub: @source_url,
        Changelog: "https://hexdocs.pm/nebulex_mnesia_adapter/changelog.html"
      }
    ]
  end
end
