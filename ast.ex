defmodule Math do
  # Since a macro receives an AST, we can pattern pattern out
  # stuff directly from the AST, do whatever we need to and then return the result
  # which should again take the AST form, here we pattern match out the following...
  # {:+, [context: Elixir, import: Kernel], [5, 2]}
  defmacro say({:+, _, [lhs, rhs]}) do
    quote do
      lhs = unquote(lhs)
      rhs = unquote(rhs)
      result = lhs + rhs
      IO.puts "#{lhs} plus #{rhs} is #{result}"
      result
    end
  end
end

# require Math
# Math.say 5 + 2
