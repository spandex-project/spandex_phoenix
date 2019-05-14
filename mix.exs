defmodule SpandexPhoenix.MixProject do
  use Mix.Project

  @version "0.4.1"

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
      maintainers: ["Zachary Daniel", "Greg Mefford"],
      licenses: ["MIT License"],
      links: %{"GitHub" => "https://github.com/spandex-project/spandex_phoenix"}
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
      {:git_ops, "~> 0.4.1", only: :dev},
      {:inch_ex, github: "rrrene/inch_ex", only: [:dev, :test]},
      {:phoenix, "~> 1.0", optional: true, only: [:dev, :test]},
      {:plug, "~> 1.3"},
      {:spandex, "~> 2.2"}
    ]
  end
end
