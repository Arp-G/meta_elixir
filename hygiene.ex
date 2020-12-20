# Hygiene Protects the Caller’s Context

# Elixir has the concept of macro hygiene. Hygiene means that variables, imports, and aliases that you define in a macro do not leak into the caller’s own definitions.
# Due to this we also requires us to be explicit about reaching into the caller’s context using something link var!

# To overide a variable in the callers context we use var! that marks that the given variable should not be hygienized so we can change it.

defmodule Setter do
  defmacro bind_name_one(string) do
    IO.puts "In macro's context (#{__MODULE__})."     # here we are in the macros context
    quote do
      IO.puts "In caller's context (#{__MODULE__})."  # Inside the quote block we are in the callers context
      name = unquote(string)                          # Won't change "name" in callers context due to macro hygiene
    end
  end
  defmacro bind_name_two(string) do
    quote do
      var!(name) = unquote(string)                    # Here using var! we explicitly marks "name" variable should not be hygienized and change the value of "name" in the callers context
    end
  end
end
defmodule Caller do
  def run do
    require Setter
    name = "Caller"                 # Set the value of "name" in the module "Caller" context
    Setter.bind_name_one("Macro")   # Trying to bind the "name" variable in the macro, this does not work because of macro hygene, since variables in macro won't leak into callers context
    IO.puts(name)  # "Caller"
    Setter.bind_name_two("Macro")    # Trying to bind the "name" variable in the macro, this works! because we use `var!` in the macro to access callers context
    IO.puts(name)  # "Macro"
  end
end
