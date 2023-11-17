defmodule Mix.Tasks.Versionset.Gen do
  @moduledoc """
  Writes or updates a version-set.json file based on git tags.
  It should be called with a path at which to place the generated version set file.

  E.g. `mix versionset.gen version-set.json`
  """
  @shortdoc "Writes or updates a version-set.json file based on git tags."

  use Mix.Task

  @impl Mix.Task
  def run([]) do
    path = Path.relative_to_cwd("../version-set.json")
    Mix.shell().info("Using a default path of #{path}")
    run([path])
  end

  def run([path]) do
    existing_version_set =
      with {:ok, contents} <- File.read(path),
           {:ok, version_set} <- Jason.decode(contents) do
        version_set
      else
        _ -> nil
      end

    if existing_version_set === nil do
      Mix.shell().info("Found existing no existing version set.")
    else
      Mix.shell().info(
        "Found the following existing version set:\n#{inspect(existing_version_set, pretty: true, width: 0)}"
      )
    end

    {raw_tags, 0} = System.cmd("git", ~w[tag --points-at HEAD])
    raw_tags = String.trim(raw_tags)

    Mix.shell().info("Found the following tags:\n#{raw_tags}")

    version_set =
      raw_tags
      |> String.split("\n")
      |> Stream.map(&String.trim/1)
      |> Stream.map(&String.split(&1, "-", parts: 2))
      |> Stream.filter(fn [name, _version] ->
        Enum.member?(["live_query", "live_query_core"], name)
      end)
      |> Stream.uniq_by(fn [name, _version] -> name end)
      |> Map.new(&List.to_tuple/1)
      |> then(fn version_set ->
        if existing_version_set do
          Map.merge(existing_version_set, version_set)
        else
          version_set
        end
      end)

    Mix.shell().info(
      "Computed the following version set:\n#{inspect(version_set, pretty: true, width: 0)}"
    )

    if Mix.shell().yes?("Would you like to write this version set?") do
      File.write!(path, Jason.encode!(version_set, pretty: true, width: 0))
      Mix.shell().info("The version set has been written to #{path}")
    end
  end
end
