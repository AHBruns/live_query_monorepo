defmodule Core.MixProject do
  use Mix.Project

  @version "0.0.0-alpha.0"
  def project do
    [
      name: "LiveQuery.Core",
      app: :live_query_core,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    []
  end
end
