defmodule SpandexPhoenix.MixProject do
  use Mix.Project

  @version "1.0.6"

  def project do
    [
      app: :spandex_phoenix,
      version: @version,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: compilers(Mix.env()),
      start_permanent: Mix.env() == :prod,
      package: package(),
      description: description(),
      docs: docs(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.circle": :test]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      name: :spandex_phoenix,
      maintainers: ["Greg Mefford"],
      licenses: ["MIT License"],
      links: %{
        "GitHub" => "https://github.com/spandex-project/spandex_phoenix",
        "Sponsor" => "https://github.com/sponsors/GregMefford"
      }
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp compilers(:test), do: [:phoenix] ++ Mix.compilers()
  defp compilers(_), do: Mix.compilers()

  defp description() do
    """
    Tools for integrating Phoenix with Spandex.
    """
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md"
      ]
    ]
  end

  defp deps do
    [
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:git_ops, "~> 2.0", only: :dev},
      {:inch_ex, "~> 2.0", only: [:dev, :test]},
      {:jason, "~> 1.0", only: [:dev, :test]},
      {:optimal, "~> 0.3"},
      {:phoenix, "~> 1.0", optional: true},
      {:phoenix_html, "~> 2.0", only: [:dev, :test]},
      {:plug, "~> 1.3"},
      {:spandex, "~> 2.2 or ~> 3.0"},
      {:telemetry, "~> 0.4 or ~> 1.0", optional: true}
    ]
  end
end
