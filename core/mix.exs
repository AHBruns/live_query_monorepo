defmodule LiveQueryCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :live_query_core,
      version: "0.0.0-alpha.0",
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
