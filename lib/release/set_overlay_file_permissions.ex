defmodule SetOverlayFilePermissions do
  use Mix.Releases.Plugin

  def after_assembly(%Release{} = release, _opts) do
    {_, path} =
      release
      |> Map.get(:resolved_overlays)
      |> Enum.find(fn {name, _path} -> name == "run" end)

    File.chmod(path, 0o755)

    release
  end

  def before_assembly(%Release{} = release, _opts), do: release

  def before_package(%Release{} = release, _opts), do: release

  def after_package(%Release{} = release, _opts), do: release

  def after_cleanup(_args, _opts), do: :ok
end
