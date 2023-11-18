defmodule LiveQuery.MixProject do
  use Mix.Project

  def project do
    [
      app: :live_query,
      version: version(),
      elixir: "~> 1.15",
      name: name(),
      description: description(),
      package: package(),
      deps: deps(),
      start_permanent: Mix.env() == :prod
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:live_query_core, "== 0.0.0-alpha.0"}
    ]
  end

  defp version() do
    "0.0.0-alpha.0"
  end

  defp name() do
    "live_query"
  end

  defp description() do
    "The whole LiveQuery suite in one package."
  end

  defp package() do
    [
      name: name(),
      files: [
        "mix.exs",
        "README.md",
        "LICENSE"
      ],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/AHBruns/live_query_monorepo"}
    ]
  end
end
