defmodule LiveQuery.MixProject do
  use Mix.Project

  def project do
    [
      app: :live_query,
      version: version(),
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp version do
    case :file.consult(~c"hex_metadata.config") do
      {:ok, data} ->
        {"version", version} = List.keyfind(data, "version", 0)
        version

      _ ->
        version =
          case System.cmd("git", ~w[describe --dirty=+dirty]) do
            {version, 0} ->
              String.trim(version)

            {_, code} ->
              Mix.shell().error("Git exited with code #{code}, falling back to 0.0.0")

              "0.0.0"
          end

        case Version.parse(version) do
          {:ok, %Version{pre: ["pre" <> _ | _]} = version} ->
            to_string(version)

          {:ok, %Version{pre: []} = version} ->
            to_string(version)

          {:ok, %Version{patch: patch, pre: pre} = version} ->
            to_string(%{version | patch: patch + 1, pre: ["dev" | pre]})

          :error ->
            Mix.shell().error("Failed to parse #{version}, falling back to 0.0.0")

            "0.0.0"
        end
    end
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:live_query_core, "== 0.0.0-alpha.0"}
    ]
  end
end
