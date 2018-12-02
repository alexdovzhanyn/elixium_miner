defmodule Util do
  @moduledoc """
    Extra utilities
  """


  @doc """
    Gets an option that was passed in as a command line argument
  """
  @spec get_arg(atom, any) :: String.t()
  def get_arg(arg, not_found \\ nil), do: Map.get(args(), arg, not_found)

  def args do
    :init.get_plain_arguments()
    |> Enum.at(1)
    |> List.to_string()
    |> String.split("--")
    |> Enum.filter(& &1 != "")
    |> Enum.map(fn a ->
         kv =
           a
           |> String.trim()
           |> String.replace(~r/\s+/, " ")
           |> String.split(" ")

         case kv do
           [key, value] -> {String.to_atom(key), value}
           [key] -> {String.to_atom(key), true}
         end
       end)
    |> Map.new()
  end

end
