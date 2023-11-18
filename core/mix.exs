defmodule Core.MixProject do
  use Mix.Project

  def project do
    [
      app: :live_query_core,
      version: version(),
      elixir: "~> 1.15",
      name: name(),
      description: description(),
      package: package(),
      deps: deps(),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp version() do
    "0.0.0-alpha.0"
  end

  defp name() do
    "LiveQuery.Core"
  end

  defp description() do
    "Core functionality for declaring and running LiveQuery queries."
  end

  defp package() do
    [
      name: name(),
      files: [
        "lib",
        ".formatter.exs",
        "mix.exs",
        "README.md",
        "LICENSE"
      ],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/AHBruns/live_query_monorepo"}
    ]
  end
end
