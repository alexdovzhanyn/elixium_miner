defmodule LoggerLevelTransformer do
  use Toml.Transform

  def transform(:level, level) when is_atom(level), do: level
  def transform(:level, level), do: String.to_atom(level)
  # Ignore all other values
  def transform(_key, v), do: v
end
