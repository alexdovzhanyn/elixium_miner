defmodule Util do
  @moduledoc """
    Extra utilities
  """


  @doc """
    Gets an option that was passed in as a command line argument
  """
  @spec get_arg(String.t() | atom, any) :: String.t()
  def get_arg(arg, not_found \\ nil)
  def get_arg(arg, not_found) when is_atom(arg), do: get_arg(Atom.to_string(arg), not_found)

  def get_arg(arg, not_found) do
    whole_arg = Enum.find(:init.get_plain_arguments(), fn argument ->
      argument
      |> List.to_string()
      |> String.starts_with?("--#{arg}=")
    end)

    case whole_arg do
      nil -> not_found
      argument ->
        [_, value] =
          argument
          |> List.to_string()
          |> String.split("--#{arg}=")
          
        value
    end
  end

end
