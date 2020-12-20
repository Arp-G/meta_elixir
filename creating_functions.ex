# Creating function on the fly using macros
defmodule Fragments do
  for {name, val} <- [one: 1, two: 2, three: 3] do
  def unquote(name)(), do: unquote(val)              # Will create functions like `def one, do: 1`
end
